import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/llm_provider.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';

class GeminiProvider implements LLMProviderService {
  final String apiKey;
  final String modelName;

  GeminiProvider({required this.apiKey, required this.modelName});

  @override
  Future<String> generateResponse({
    required String prompt,
    required List<MentorMessage> history,
    required String systemInstruction,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('No Gemini API key provided');
    }

    final contents = <Map<String, dynamic>>[];

    for (int i = 0; i < history.length - 1; i++) {
      final msg = history[i];
      final apiRole = msg.role == 'model' ? 'model' : 'user';
      contents.add({
        'role': apiRole,
        'parts': [
          {'text': msg.content}
        ]
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt}
      ]
    });

    final actualModelName = modelName.isEmpty ? 'gemini-3.6-flash' : modelName;
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$actualModelName:generateContent?key=$apiKey');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
        'contents': contents,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('Gemini API returned an empty text message.');
    }

    return text;
  }
}
