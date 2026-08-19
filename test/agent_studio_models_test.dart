import 'package:demo_ai_even/agent_studio/agent_studio_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentStudioReply', () {
    test('parses a nested concierge response', () {
      final reply = AgentStudioReply.fromJson(
        <String, dynamic>{
          'request_id': 'req-1',
          'thread_id': 'thread-1',
          'reply': <String, dynamic>{
            'display_text': 'The game loop is healthy.',
            'spoken_text': 'The game loop is healthy and on schedule.',
          },
          'task': <String, dynamic>{
            'id': 'task-1',
            'status': 'running',
            'summary': 'Audit the game loop',
          },
        },
        fallbackRequestId: 'fallback',
      );

      expect(reply.requestId, 'req-1');
      expect(reply.threadId, 'thread-1');
      expect(reply.displayText, 'The game loop is healthy.');
      expect(
        reply.spokenText,
        'The game loop is healthy and on schedule.',
      );
      expect(reply.task?.id, 'task-1');
    });

    test('rejects a response with no readable text', () {
      expect(
        () => AgentStudioReply.fromJson(
          <String, dynamic>{'request_id': 'req-2'},
          fallbackRequestId: 'fallback',
        ),
        throwsA(isA<AgentStudioProtocolException>()),
      );
    });
  });

  test('parses a replayable event sequence', () {
    final event = AgentStudioEvent.fromJson(<String, dynamic>{
      'event_id': 'event-1',
      'type': 'task.completed',
      'sequence': 42,
      'task_id': 'task-1',
      'payload': <String, dynamic>{
        'summary': 'The audit completed.',
      },
    });

    expect(event.id, 'event-1');
    expect(event.sequence, 42);
    expect(event.taskId, 'task-1');
    expect(event.payload['summary'], 'The audit completed.');
  });
}
