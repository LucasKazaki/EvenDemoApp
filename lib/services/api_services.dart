import 'package:demo_ai_even/agent_studio/agent_studio_client.dart';
import 'package:demo_ai_even/agent_studio/agent_studio_models.dart';

/// Legacy compatibility adapter.
///
/// All requests now go to Agent Studio, which selects the appropriate local or
/// cloud model and returns a device-safe response.
class ApiService {
  ApiService({AgentStudioClient? client})
      : _client = client ?? AgentStudioClient.instance;

  final AgentStudioClient _client;

  Future<String> sendChatRequest(String question) async {
    try {
      final reply = await _client.sendMessage(
        question,
        source: 'even_g1',
      );
      return reply.displayText;
    } on AgentStudioNotConfiguredException {
      return 'Open Agent Studio settings in the phone app and pair this device.';
    } on AgentStudioException catch (error) {
      return error.message;
    } catch (_) {
      return 'Agent Studio could not complete this request.';
    }
  }
}
