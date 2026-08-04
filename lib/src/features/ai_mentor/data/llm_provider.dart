import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

import 'providers/open_router_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/claude_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/groq_provider.dart';

abstract class LLMProviderService {
  /// Generates a response from the LLM provider based on the given prompt and conversation history.
  Future<String> generateResponse({
    required String prompt,
    required List<MentorMessage> history,
    required String systemInstruction,
  });
}

final llmServiceProvider = Provider<LLMProviderService>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  
  switch (settings.llmProvider) {
    case LLMProviderType.openRouter:
      return OpenRouterProvider(
        apiKey: settings.openRouterApiKey,
        modelName: settings.openRouterModel,
      );
    case LLMProviderType.gemini:
      return GeminiProvider(
        apiKey: settings.geminiApiKey,
        modelName: settings.geminiModel,
      );
    case LLMProviderType.openAI:
      return OpenAIProvider(
        apiKey: settings.openAIApiKey,
        modelName: settings.openAIModel,
      );
    case LLMProviderType.claude:
      return ClaudeProvider(
        apiKey: settings.claudeApiKey,
        modelName: settings.claudeModel,
      );
    case LLMProviderType.ollama:
      return OllamaProvider(
        baseUrl: settings.ollamaBaseUrl,
        modelName: settings.ollamaModel,
      );
    case LLMProviderType.groq:
      return GroqProvider(
        apiKey: settings.groqApiKey,
        modelName: settings.groqModel,
      );
  }
});
