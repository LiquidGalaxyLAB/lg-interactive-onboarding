import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/llm_provider.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

class OpenRouterProvider implements LLMProviderService {
  final String apiKey;
  final String modelName;

  OpenRouterProvider({required this.apiKey, required this.modelName});

  @override
  Future<String> generateResponse({
    required String prompt,
    required List<MentorMessage> history,
    required String systemInstruction,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('No OpenRouter API key provided');
    }

    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemInstruction});

    for (int i = 0; i < history.length - 1; i++) {
      final msg = history[i];
      final apiRole = msg.role == 'model' ? 'assistant' : 'user';
      messages.add({'role': apiRole, 'content': msg.content});
    }

    messages.add({'role': 'user', 'content': prompt});

    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://github.com/LiquidGalaxyLAB',
        'X-Title': 'LG Interactive Onboarding',
      },
      body: jsonEncode({
        'model': modelName.isEmpty ? 'inclusionai/ling-3.0-flash:free' : modelName,
        'messages': messages,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenRouter API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['choices']?[0]?['message']?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('OpenRouter API returned an empty text message.');
    }

    return text;
  }
}
