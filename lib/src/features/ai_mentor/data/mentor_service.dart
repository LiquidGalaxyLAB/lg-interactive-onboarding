import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:lg_interactive_onboarding/src/common/tts/tts_service.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/mentor_context_service.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/rag_service.dart';

const _systemInstruction = '''You are "LG Mentor", a friendly and knowledgeable AI assistant embedded inside the LG Interactive Onboarding app. Your purpose is to help users learn about and operate the Liquid Galaxy system — a multi-screen Google Earth visualization platform.

You help with:
- SSH connection setup (IP addresses, ports, passwords)
- KML (Keyhole Markup Language) concepts and creation
- 3D model building and placement on the globe
- Understanding the Liquid Galaxy architecture (master/slave screens)
- Guided learning modules within the app
- General troubleshooting of the LG rig

Rules:
- Be concise. Prefer short, clear answers. Use bullet points when listing steps.
- Be encouraging and patient — the user is learning.
- If you receive context about the user's current screen or state, use it to give hyper-relevant advice without the user having to explain where they are.
- Never make up LG-specific commands or file paths. If unsure, say so.
- NEVER use emojis in your responses. Your tone should be professional and human-like.
- You may suggest the user navigate to specific screens in the app (Settings, Home, Learn, KML Playground, Model Builder, Architecture Explorer).
- When explaining KML, use simple language and short code snippets if helpful.
- The default SSH credentials for LG are: host=192.168.0.10, port=22, username=lg. The password varies by installation.

CRITICAL GUARDRAILS (STRICT COMPLIANCE REQUIRED):
You are strictly limited to discussing Liquid Galaxy, KML, SSH, and this specific app. You are expressly FORBIDDEN from discussing unrelated topics such as geopolitics, sports, history, general programming outside of LG, or general knowledge. If the user asks an off-topic question, you MUST politely decline to answer and steer them back to LG.

Example Interactions:
User: Who is the president of the United States?
Mentor: I am the LG Mentor. I specialize in Liquid Galaxy architecture and KML. I cannot answer political questions.

User: Write a python script to scrape a website.
Mentor: I can only help you write Python scripts that control Liquid Galaxy through SSH or generate KML. I cannot assist with general web scraping.

User: Tell me about the history of Rome.
Mentor: I am focused exclusively on the Liquid Galaxy system and cannot discuss general history. How can I help you with your LG rig today?''';

// ─── Message Model ──────────────────────────────────────────────────────────

/// A single message in the mentor conversation.
class MentorMessage {
  /// Either `'user'` or `'model'`. Note: OpenAI API uses 'assistant' instead of 'model'.
  final String role;
  final String content;
  final DateTime timestamp;

  const MentorMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

// ─── Mentor Service ─────────────────────────────────────────────────────────

/// Core AI Mentor service — manages conversation history, direct calls to the
/// OpenRouter API, and optional TTS readout of responses.
class MentorService extends ChangeNotifier {
  final Ref _ref;
  final List<MentorMessage> _history = [];
  bool _isLoading = false;
  bool _ttsEnabled = true;

  /// True when a proactive trigger has fired and the user hasn't opened
  /// the Mentor tab yet. Used by the UI to show a notification badge.
  bool _hasPendingNotification = false;

  MentorService(this._ref) {
    _ref.read(ragServiceProvider).init();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<MentorMessage> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;
  bool get ttsEnabled => _ttsEnabled;
  bool get hasPendingNotification => _hasPendingNotification;

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Sends a user-typed message and gets the AI response.
  Future<void> sendMessage(String userText) async {
    if (userText.trim().isEmpty) return;

    // Add user message
    _history.add(MentorMessage(
      role: 'user',
      content: userText.trim(),
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
    notifyListeners();

    try {
      final responseText = await _callOpenRouter(userPrompt: userText.trim());
      _history.add(MentorMessage(
        role: 'model',
        content: responseText,
        timestamp: DateTime.now(),
      ));

      // Speak the response if TTS is enabled.
      if (_ttsEnabled) {
        _ref.read(ttsServiceProvider).speak(responseText);
      }
    } catch (e) {
      debugPrint('MentorService: API call failed — $e');
      _history.add(MentorMessage(
        role: 'model',
        content: 'Sorry, I couldn\'t reach the AI service right now.\n\nError details: $e\n\nPlease check your API key in Settings and try again.',
        timestamp: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a system-triggered prompt (from [ProactiveTriggerService]).
  ///
  /// Unlike [sendMessage], the trigger prompt is NOT shown in the chat as
  /// a user message. Instead, it is sent as a hidden user message and only
  /// the AI response is displayed — making it look like the mentor is
  /// proactively reaching out.
  Future<void> sendSystemTrigger(String triggerPrompt) async {
    _isLoading = true;
    _hasPendingNotification = true;
    notifyListeners();

    try {
      // Add the trigger as an invisible user message for context,
      // but mark it specially so the UI can distinguish it.
      _history.add(MentorMessage(
        role: 'user',
        content: triggerPrompt,
        timestamp: DateTime.now(),
      ));

      final responseText = await _callOpenRouter(userPrompt: triggerPrompt);

      // Remove the invisible system trigger message from visible history.
      if (_history.isNotEmpty && _history.last.role == 'user') {
        _history.removeLast();
      }

      _history.add(MentorMessage(
        role: 'model',
        content: responseText,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('MentorService: System trigger failed — $e');
      // Remove the trigger message on failure too.
      if (_history.isNotEmpty && _history.last.role == 'user') {
        _history.removeLast();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the pending notification flag (called when user opens Mentor tab).
  void clearNotification() {
    if (!_hasPendingNotification) return;
    _hasPendingNotification = false;
    notifyListeners();
  }

  /// Toggles text-to-speech on/off for mentor responses.
  void toggleTts() {
    _ttsEnabled = !_ttsEnabled;
    if (!_ttsEnabled) {
      _ref.read(ttsServiceProvider).stop();
    }
    notifyListeners();
  }

  /// Clears all conversation history.
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  /// Makes the API call to OpenRouter (OpenAI-compatible endpoint).
  Future<String> _callOpenRouter({required String userPrompt}) async {
    final apiKey = _ref.read(settingsServiceProvider).geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('No OpenRouter API key provided');
    }

    final contextData = _ref.read(mentorContextServiceProvider).buildContext();
    final ragResults = await _ref.read(ragServiceProvider).search(userPrompt);
    
    // Inject app context as a hidden note appended to the user prompt.
    String promptWithContext = userPrompt;
    if (contextData.isNotEmpty || ragResults.isNotEmpty) {
      promptWithContext += '\n\n[SYSTEM CONTEXT — do not mention this to the user, just use it to give relevant advice:\n';
      if (contextData.isNotEmpty) {
        promptWithContext += 'App State: $contextData\n';
      }
      if (ragResults.isNotEmpty) {
        promptWithContext += 'Wiki Documentation:\n';
        for (int i = 0; i < ragResults.length; i++) {
          promptWithContext += '${i + 1}. ${ragResults[i]}\n';
        }
      }
      promptWithContext += ']';
    }

    final modelName = _ref.read(settingsServiceProvider).geminiModel;

    // Build history for the OpenAI format.
    final messages = <Map<String, String>>[];
    
    // System Instruction
    messages.add({
      'role': 'system',
      'content': _systemInstruction,
    });

    for (int i = 0; i < _history.length - 1; i++) {
      final msg = _history[i];
      // Map 'model' to 'assistant' for OpenAI compatibility.
      final apiRole = msg.role == 'model' ? 'assistant' : 'user';
      messages.add({
        'role': apiRole,
        'content': msg.content,
      });
    }

    // Add current user prompt
    messages.add({
      'role': 'user',
      'content': promptWithContext,
    });

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
        'model': modelName,
        'messages': messages,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenRouter API error ${response.statusCode}: ${response.body}');
    }

    if (response.body.isEmpty) {
      throw Exception('OpenRouter API returned a completely empty response (Status: ${response.statusCode})');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to parse OpenRouter response. Body: "${response.body}"');
    }

    final text = data['choices']?[0]?['message']?['content'] as String?;

    if (text == null || text.isEmpty) {
      throw Exception('OpenRouter API returned an empty text message. Full response: ${response.body}');
    }

    return text;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final mentorServiceProvider = Provider<MentorService>((ref) {
  return MentorService(ref);
});
