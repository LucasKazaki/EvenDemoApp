class AgentStudioTaskRef {
  const AgentStudioTaskRef({
    required this.id,
    required this.status,
    this.summary,
  });

  final String id;
  final String status;
  final String? summary;

  factory AgentStudioTaskRef.fromJson(Map<String, dynamic> json) {
    return AgentStudioTaskRef(
      id: (json['id'] ?? json['task_id'] ?? '').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      summary: json['summary']?.toString(),
    );
  }
}

class AgentStudioReply {
  const AgentStudioReply({
    required this.requestId,
    required this.displayText,
    required this.spokenText,
    this.threadId,
    this.messageId,
    this.task,
    this.raw = const <String, dynamic>{},
  });

  final String requestId;
  final String displayText;
  final String spokenText;
  final String? threadId;
  final String? messageId;
  final AgentStudioTaskRef? task;
  final Map<String, dynamic> raw;

  factory AgentStudioReply.fromJson(
    Map<String, dynamic> json, {
    required String fallbackRequestId,
  }) {
    final reply = _asMap(json['reply']);
    final message = _asMap(json['message']);

    final text = _firstNonEmpty(<dynamic>[
      reply['display_text'],
      reply['text'],
      json['display_text'],
      json['text'],
      message['content'],
      json['content'],
    ]);

    if (text == null) {
      throw const AgentStudioProtocolException(
        'Agent Studio returned no readable reply text.',
      );
    }

    final spokenText = _firstNonEmpty(<dynamic>[
          reply['spoken_text'],
          json['spoken_text'],
        ]) ??
        text;

    final taskJson = _asMap(json['task']);

    return AgentStudioReply(
      requestId: _firstNonEmpty(<dynamic>[
            json['request_id'],
            json['requestId'],
          ]) ??
          fallbackRequestId,
      threadId: _firstNonEmpty(<dynamic>[
        json['thread_id'],
        json['threadId'],
      ]),
      messageId: _firstNonEmpty(<dynamic>[
        json['message_id'],
        json['messageId'],
        message['id'],
      ]),
      displayText: text,
      spokenText: spokenText,
      task: taskJson.isEmpty ? null : AgentStudioTaskRef.fromJson(taskJson),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }
}

class AgentStudioEvent {
  const AgentStudioEvent({
    required this.id,
    required this.type,
    required this.payload,
    this.sequence,
    this.projectId,
    this.threadId,
    this.taskId,
  });

  final String id;
  final String type;
  final int? sequence;
  final String? projectId;
  final String? threadId;
  final String? taskId;
  final Map<String, dynamic> payload;

  factory AgentStudioEvent.fromJson(Map<String, dynamic> json) {
    return AgentStudioEvent(
      id: (json['id'] ?? json['event_id'] ?? '').toString(),
      type: (json['type'] ?? 'unknown').toString(),
      sequence: _asInt(json['sequence']),
      projectId: json['project_id']?.toString(),
      threadId: json['thread_id']?.toString(),
      taskId: json['task_id']?.toString(),
      payload: Map<String, dynamic>.unmodifiable(_asMap(json['payload'])),
    );
  }
}

class AgentStudioException implements Exception {
  const AgentStudioException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AgentStudioNotConfiguredException extends AgentStudioException {
  const AgentStudioNotConfiguredException()
      : super('Agent Studio is not configured on this device.');
}

class AgentStudioProtocolException extends AgentStudioException {
  const AgentStudioProtocolException(super.message, {super.cause});
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

String? _firstNonEmpty(Iterable<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '');
}
