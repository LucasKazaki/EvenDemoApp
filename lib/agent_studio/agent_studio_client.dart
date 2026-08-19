import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'agent_studio_config.dart';
import 'agent_studio_models.dart';

class AgentStudioClient {
  AgentStudioClient._();

  static final AgentStudioClient instance = AgentStudioClient._();

  final AgentStudioConfigStore _configStore = AgentStudioConfigStore.instance;

  Future<AgentStudioReply> sendMessage(
    String text, {
    String source = 'even_g1',
    String? threadId,
    String? projectId,
    bool allowNewThread = true,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AgentStudioProtocolException('The message is empty.');
    }

    final config = await _requireConfig();
    final requestId = const Uuid().v4();
    final effectiveProjectId = projectId ?? config.projectId;

    final body = <String, dynamic>{
      'request_id': requestId,
      'source': source,
      'input': <String, dynamic>{
        'type': 'text',
        'text': trimmed,
      },
      'routing': <String, dynamic>{
        'mode': 'auto',
        'allow_new_thread': allowNewThread,
        if (threadId != null && threadId.isNotEmpty) 'thread_id': threadId,
        if (effectiveProjectId != null && effectiveProjectId.isNotEmpty)
          'project_id': effectiveProjectId,
      },
      'client': <String, dynamic>{
        'device_id': config.deviceId,
        'device_type': 'even_g1_companion',
        'capabilities': <String>[
          'g1.microphone',
          'g1.display.text',
          'g1.touchbar',
        ],
      },
      'response': <String, dynamic>{
        'mode': 'concise',
        'max_display_characters': 900,
      },
    };

    final dio = _buildDio(config);
    try {
      final response = await dio.postUri<dynamic>(
        config.endpoint('/api/v1/messages'),
        data: body,
        options: Options(
          headers: <String, String>{
            'Idempotency-Key': requestId,
            'X-Agent-Studio-Device': config.deviceId,
          },
        ),
      );

      final data = _decodeMap(response.data);
      return AgentStudioReply.fromJson(
        data,
        fallbackRequestId: requestId,
      );
    } on DioException catch (error) {
      throw AgentStudioException(
        _friendlyNetworkMessage(error),
        cause: error,
      );
    } on FormatException catch (error) {
      throw AgentStudioProtocolException(
        'Agent Studio returned malformed JSON.',
        cause: error,
      );
    }
  }

  Future<bool> healthCheck() async {
    final config = await _requireConfig();
    final dio = _buildDio(config);
    try {
      final response = await dio.getUri<dynamic>(
        config.endpoint('/api/v1/health'),
      );
      return response.statusCode != null && response.statusCode! < 400;
    } on DioException {
      return false;
    }
  }

  AgentStudioEventStream eventStream({
    void Function(AgentStudioEvent event)? onEvent,
  }) {
    return AgentStudioEventStream(
      configStore: _configStore,
      onEvent: onEvent,
    );
  }

  Dio _buildDio(AgentStudioConfig config) {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        responseType: ResponseType.json,
        headers: <String, String>{
          HttpHeaders.authorizationHeader: 'Bearer ${config.deviceToken}',
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.acceptHeader: 'application/json',
        },
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );
  }

  Future<AgentStudioConfig> _requireConfig() async {
    final config = await _configStore.load();
    if (!config.isConfigured) {
      throw const AgentStudioNotConfiguredException();
    }
    return config;
  }

  Map<String, dynamic> _decodeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    }
    throw const FormatException('Expected a JSON object.');
  }

  String _friendlyNetworkMessage(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Agent Studio rejected this device token.';
    }
    if (status == 404) {
      return 'The Agent Studio message endpoint was not found.';
    }
    if (status != null && status >= 500) {
      return 'Agent Studio is temporarily unavailable.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Agent Studio timed out.';
    }
    return 'Unable to reach Agent Studio.';
  }
}

class AgentStudioEventStream {
  AgentStudioEventStream({
    required AgentStudioConfigStore configStore,
    this.onEvent,
  }) : _configStore = configStore;

  final AgentStudioConfigStore _configStore;
  final void Function(AgentStudioEvent event)? onEvent;
  final StreamController<AgentStudioEvent> _controller =
      StreamController<AgentStudioEvent>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  int? _lastSequence;
  bool _closed = false;

  Stream<AgentStudioEvent> get events => _controller.stream;

  Future<void> connect() async {
    if (_closed) {
      throw StateError('This event stream has been closed.');
    }

    final config = await _configStore.load();
    if (!config.isConfigured) {
      throw const AgentStudioNotConfiguredException();
    }

    await _subscription?.cancel();
    await _channel?.sink.close();

    final uri = config.websocketEndpoint(
      '/api/v1/events',
      query: <String, String>{
        'device_id': config.deviceId,
        if (_lastSequence != null) 'after': _lastSequence.toString(),
      },
    );

    final channel = IOWebSocketChannel.connect(
      uri,
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer ${config.deviceToken}',
        'X-Agent-Studio-Device': config.deviceId,
      },
      connectTimeout: const Duration(seconds: 12),
      pingInterval: const Duration(seconds: 20),
    );
    _channel = channel;

    try {
      await channel.ready;
      _reconnectAttempt = 0;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: _handleDisconnect,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
      rethrow;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = message is String ? jsonDecode(message) : message;
      if (decoded is! Map) {
        return;
      }
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      final event = AgentStudioEvent.fromJson(map);
      if (event.sequence != null) {
        _lastSequence = event.sequence;
      }
      onEvent?.call(event);
      _controller.add(event);
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  void _handleDisconnect([Object? error, StackTrace? stackTrace]) {
    if (error != null) {
      _controller.addError(error, stackTrace);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _reconnectTimer?.isActive == true) {
      return;
    }
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 8);
    final seconds = 1 << (_reconnectAttempt - 1);
    _reconnectTimer = Timer(
      Duration(seconds: seconds.clamp(1, 60)),
      () => connect().catchError((_) {}),
    );
  }

  Future<void> close() async {
    _closed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _controller.close();
  }
}
