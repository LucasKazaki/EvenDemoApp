import 'dart:async';

import 'package:demo_ai_even/ble_manager.dart';
import 'package:demo_ai_even/services/evenai.dart';
import 'package:demo_ai_even/services/text_service.dart';

import 'agent_studio_client.dart';
import 'agent_studio_models.dart';

/// Maintains the background event connection between the phone companion and
/// Agent Studio, then renders only high-value, glanceable events on the G1.
///
/// This service deliberately does not approve consequential actions from the
/// glasses. Approval events are informational and should deep-link to the phone
/// application in a later phase.
class AgentStudioRuntime {
  AgentStudioRuntime._();

  static final AgentStudioRuntime instance = AgentStudioRuntime._();

  final StreamController<AgentStudioEvent> _events =
      StreamController<AgentStudioEvent>.broadcast();
  final Set<String> _seenEventIds = <String>{};

  AgentStudioEventStream? _eventStream;
  StreamSubscription<AgentStudioEvent>? _subscription;
  Timer? _displayCooldown;
  AgentStudioEvent? _pendingDisplayEvent;
  bool _starting = false;

  Stream<AgentStudioEvent> get events => _events.stream;

  Future<void> start() async {
    if (_starting || _eventStream != null) {
      return;
    }
    _starting = true;

    try {
      final stream = AgentStudioClient.instance.eventStream();
      _eventStream = stream;
      _subscription = stream.events.listen(
        _handleEvent,
        onError: (_) {},
      );
      await stream.connect();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      await _eventStream?.close();
      _eventStream = null;
    } finally {
      _starting = false;
    }
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  Future<void> stop() async {
    _displayCooldown?.cancel();
    _displayCooldown = null;
    _pendingDisplayEvent = null;
    await _subscription?.cancel();
    _subscription = null;
    await _eventStream?.close();
    _eventStream = null;
  }

  void _handleEvent(AgentStudioEvent event) {
    if (event.id.isNotEmpty && !_seenEventIds.add(event.id)) {
      return;
    }
    if (_seenEventIds.length > 500) {
      _seenEventIds.remove(_seenEventIds.first);
    }

    _events.add(event);

    if (!_isGlanceable(event)) {
      return;
    }

    if (_displayCooldown?.isActive == true) {
      _pendingDisplayEvent = event;
      return;
    }

    unawaited(_displayEvent(event));
  }

  bool _isGlanceable(AgentStudioEvent event) {
    return const <String>{
      'approval.requested',
      'task.blocked',
      'task.completed',
      'task.failed',
      'run.failed',
      'agent.alert',
      'agent.message',
    }.contains(event.type);
  }

  Future<void> _displayEvent(AgentStudioEvent event) async {
    _displayCooldown = Timer(const Duration(seconds: 8), () {
      final pending = _pendingDisplayEvent;
      _pendingDisplayEvent = null;
      if (pending != null) {
        unawaited(_displayEvent(pending));
      }
    });

    if (!BleManager.get().isConnected || EvenAI.isRunning) {
      return;
    }

    final text = _formatForGlasses(event);
    if (text.isEmpty) {
      return;
    }

    await TextService.get.startSendText(text);
  }

  String _formatForGlasses(AgentStudioEvent event) {
    final payload = event.payload;
    final title = _firstText(<dynamic>[
          payload['title'],
          payload['display_title'],
        ]) ??
        _defaultTitle(event.type);
    final body = _firstText(<dynamic>[
      payload['display_text'],
      payload['summary'],
      payload['message'],
      payload['reason'],
      payload['error'],
    ]);

    if (body == null) {
      return title;
    }

    final compactBody = body.length > 500 ? '${body.substring(0, 497)}...' : body;
    return '$title\n$compactBody';
  }

  String _defaultTitle(String type) {
    return switch (type) {
      'approval.requested' => 'Approval needed',
      'task.blocked' => 'Task blocked',
      'task.completed' => 'Task completed',
      'task.failed' || 'run.failed' => 'Task failed',
      'agent.alert' => 'Agent Studio alert',
      _ => 'Agent Studio',
    };
  }

  String? _firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }
}
