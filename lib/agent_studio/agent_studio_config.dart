import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AgentStudioConfig {
  const AgentStudioConfig({
    required this.baseUrl,
    required this.deviceToken,
    required this.deviceId,
    this.projectId,
  });

  final String baseUrl;
  final String deviceToken;
  final String deviceId;
  final String? projectId;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      deviceToken.trim().isNotEmpty &&
      deviceId.trim().isNotEmpty;

  String get normalizedBaseUrl {
    var value = baseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Uri endpoint(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBaseUrl$normalizedPath');
  }

  Uri websocketEndpoint(String path, {Map<String, String>? query}) {
    final httpUri = endpoint(path);
    final scheme = switch (httpUri.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => throw FormatException(
          'Agent Studio URL must begin with https:// or http://.',
        ),
    };
    return httpUri.replace(scheme: scheme, queryParameters: query);
  }

  AgentStudioConfig copyWith({
    String? baseUrl,
    String? deviceToken,
    String? deviceId,
    String? projectId,
    bool clearProjectId = false,
  }) {
    return AgentStudioConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      deviceToken: deviceToken ?? this.deviceToken,
      deviceId: deviceId ?? this.deviceId,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
    );
  }
}

class AgentStudioConfigStore {
  AgentStudioConfigStore._();

  static final AgentStudioConfigStore instance = AgentStudioConfigStore._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _baseUrlKey = 'agent_studio.base_url';
  static const _deviceTokenKey = 'agent_studio.device_token';
  static const _deviceIdKey = 'agent_studio.device_id';
  static const _projectIdKey = 'agent_studio.project_id';

  static const _environmentBaseUrl = String.fromEnvironment(
    'AGENT_STUDIO_BASE_URL',
    defaultValue: '',
  );
  static const _environmentToken = String.fromEnvironment(
    'AGENT_STUDIO_DEVICE_TOKEN',
    defaultValue: '',
  );
  static const _environmentProjectId = String.fromEnvironment(
    'AGENT_STUDIO_PROJECT_ID',
    defaultValue: '',
  );

  AgentStudioConfig? _cached;

  Future<AgentStudioConfig> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) {
      return _cached!;
    }

    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.trim().isEmpty) {
      deviceId = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }

    final storedBaseUrl = await _storage.read(key: _baseUrlKey);
    final storedToken = await _storage.read(key: _deviceTokenKey);
    final storedProjectId = await _storage.read(key: _projectIdKey);

    _cached = AgentStudioConfig(
      baseUrl: _firstConfigured(storedBaseUrl, _environmentBaseUrl),
      deviceToken: _firstConfigured(storedToken, _environmentToken),
      deviceId: deviceId,
      projectId: _nullableConfigured(
        storedProjectId,
        _environmentProjectId,
      ),
    );
    return _cached!;
  }

  Future<void> save(AgentStudioConfig config) async {
    final uri = Uri.tryParse(config.normalizedBaseUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const FormatException('Enter a complete Agent Studio URL.');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('Agent Studio must use HTTPS or HTTP.');
    }

    await _storage.write(key: _baseUrlKey, value: config.normalizedBaseUrl);
    await _storage.write(key: _deviceTokenKey, value: config.deviceToken.trim());
    await _storage.write(key: _deviceIdKey, value: config.deviceId.trim());

    final projectId = config.projectId?.trim();
    if (projectId == null || projectId.isEmpty) {
      await _storage.delete(key: _projectIdKey);
    } else {
      await _storage.write(key: _projectIdKey, value: projectId);
    }

    _cached = config.copyWith(
      baseUrl: config.normalizedBaseUrl,
      deviceToken: config.deviceToken.trim(),
      deviceId: config.deviceId.trim(),
      projectId: projectId,
      clearProjectId: projectId == null || projectId.isEmpty,
    );
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _deviceTokenKey);
    _cached = null;
  }

  String _firstConfigured(String? stored, String environment) {
    final storedValue = stored?.trim();
    if (storedValue != null && storedValue.isNotEmpty) {
      return storedValue;
    }
    return environment.trim();
  }

  String? _nullableConfigured(String? stored, String environment) {
    final value = _firstConfigured(stored, environment);
    return value.isEmpty ? null : value;
  }
}
