import 'package:demo_ai_even/agent_studio/agent_studio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentStudioConfig', () {
    test('normalizes REST endpoints', () {
      const config = AgentStudioConfig(
        baseUrl: 'https://agent-studio.example.ts.net/',
        deviceToken: 'token',
        deviceId: 'device',
      );

      expect(
        config.endpoint('/api/v1/health').toString(),
        'https://agent-studio.example.ts.net/api/v1/health',
      );
    });

    test('converts HTTPS endpoints to secure WebSockets', () {
      const config = AgentStudioConfig(
        baseUrl: 'https://agent-studio.example.ts.net',
        deviceToken: 'token',
        deviceId: 'device',
      );

      expect(
        config.websocketEndpoint('/api/v1/events').scheme,
        'wss',
      );
    });
  });
}
