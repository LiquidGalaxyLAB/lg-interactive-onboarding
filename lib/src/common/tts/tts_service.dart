import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Text-to-speech service for voice narration throughout the app.
///
/// Extends [ChangeNotifier] so that widgets watching [ttsServiceProvider]
/// (via [ChangeNotifierProvider]) rebuild when [isEnabled] changes — e.g.
/// to update the mute/unmute icon without requiring a separate state layer.
class TTSService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isEnabled = true;

  final String _initialVoice;

  TTSService(this._initialVoice) {
    _init();
  }

  Future<void> _init() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      
      if (_initialVoice.isNotEmpty) {
        final voices = await _flutterTts.getVoices;
        if (voices != null) {
          for (var v in voices) {
            final map = Map<String, String>.from(v as Map);
            if (map['name'] == _initialVoice) {
              await _flutterTts.setVoice({"name": map['name']!, "locale": map['locale'] ?? "en-US"});
              break;
            }
          }
        }
      }
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTSService: error — $msg');
        _isSpeaking = false;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('TTSService: init failed — $e');
    }
  }

  /// Speaks [text] aloud. If narration is disabled or [text] is empty, no-op.
  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    await stop();
    _isSpeaking = true;
    notifyListeners();
    await _flutterTts.speak(text);
  }

  /// Stops any in-progress utterance immediately.
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    }
  }

  /// Enables or disables narration. Rebuilds any watching widgets.
  void setEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    if (!value) stop();
    notifyListeners();
  }

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;

  /// Fetches available voices, filters for English, and maps them to friendly names.
  Future<List<Map<String, String>>> getAvailableVoices() async {
    final voices = await _flutterTts.getVoices;
    if (voices == null) return [];

    return (voices as Iterable)
        .map<Map<String, String>>((v) => Map<String, String>.from(v as Map))
        .where((map) => (map['locale']?.toLowerCase() ?? '').startsWith('en'))
        .take(10) // Limit to 10 voices
        .map<Map<String, String>>((map) => {
              'name': map['name'] ?? '',
              'locale': map['locale'] ?? '',
              'displayName': _formatVoiceName(map['name'] ?? 'Voice'),
            })
        .toList();
  }

  String _formatVoiceName(String internalName) {
    String name = internalName;
    // Try to extract the readable part if it's a bundle ID format (e.g. com.apple...)
    if (name.contains('.')) {
      name = name.split('.').last;
    }
    
    // Capitalize first letter
    if (name.isNotEmpty) {
      name = name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }

  /// Sets the TTS voice by name.
  Future<void> setVoice(String voiceName, String locale) async {
    await _flutterTts.setVoice({"name": voiceName, "locale": locale});
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Singleton TTS service — use [ChangeNotifierProvider] so widgets can
/// reactively watch [TTSService.isEnabled] and [TTSService.isSpeaking].
final ttsServiceProvider = Provider<TTSService>((ref) {
  final settings = ref.read(settingsServiceProvider);
  final tts = TTSService(settings.ttsVoice);
  tts.setEnabled(settings.voiceNarration);
  return tts;
});
