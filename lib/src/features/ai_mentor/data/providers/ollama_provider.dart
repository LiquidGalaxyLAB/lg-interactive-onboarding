import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/llm_provider.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

class OllamaProvider implements LLMProviderService {
  final String baseUrl;
  final String modelName;

  OllamaProvider({required this.baseUrl, required this.modelName});

  @override
  Future<String> generateResponse({
    required String prompt,
    required List<MentorMessage> history,
    required String systemInstruction,
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception('No Ollama Base URL provided');
    }

    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemInstruction});

    for (int i = 0; i < history.length - 1; i++) {
      final msg = history[i];
      final apiRole = msg.role == 'model' ? 'assistant' : 'user';
      messages.add({'role': apiRole, 'content': msg.content});
    }

    messages.add({'role': 'user', 'content': prompt});

    // Make sure baseUrl doesn't have trailing slash
    final normalizedUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$normalizedUrl/api/chat');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': modelName.isEmpty ? 'llama3' : modelName,
        'messages': messages,
        'stream': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ollama API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['message']?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('Ollama API returned an empty text message.');
    }

    return text;
  }
}
