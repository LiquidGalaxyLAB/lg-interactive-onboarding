import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/llm_provider.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

class ClaudeProvider implements LLMProviderService {
  final String apiKey;
  final String modelName;

  ClaudeProvider({required this.apiKey, required this.modelName});

  @override
  Future<String> generateResponse({
    required String prompt,
    required List<MentorMessage> history,
    required String systemInstruction,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('No Anthropic/Claude API key provided');
    }

    final messages = <Map<String, String>>[];

    for (int i = 0; i < history.length - 1; i++) {
      final msg = history[i];
      final apiRole = msg.role == 'model' ? 'assistant' : 'user';
      messages.add({'role': apiRole, 'content': msg.content});
    }

    messages.add({'role': 'user', 'content': prompt});

    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': modelName.isEmpty ? 'claude-3-haiku-20240307' : modelName,
        'system': systemInstruction,
        'messages': messages,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['content']?[0]?['text'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('Claude API returned an empty text message.');
    }

    return text;
  }
}
