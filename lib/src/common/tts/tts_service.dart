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

    final maleNames = ['Alex', 'Daniel', 'Thomas', 'Oliver', 'George'];
    final femaleNames = ['Samantha', 'Karen', 'Moira', 'Fiona', 'Isla'];
    
    List<Map<String, String>> finalVoices = [];
    int maleCount = 0;
    int femaleCount = 0;
    
    for (var v in voices) {
      final map = Map<String, String>.from(v as Map);
      final locale = map['locale']?.toLowerCase() ?? '';
      final name = map['name']?.toLowerCase() ?? '';
      
      if (locale.startsWith('en')) {
        if (name.contains('female') && femaleCount < femaleNames.length) {
          finalVoices.add({
            'name': map['name'] ?? '',
            'locale': map['locale'] ?? '',
            'displayName': femaleNames[femaleCount],
          });
          femaleCount++;
        } else if (name.contains('male') && !name.contains('female') && maleCount < maleNames.length) {
          finalVoices.add({
            'name': map['name'] ?? '',
            'locale': map['locale'] ?? '',
            'displayName': maleNames[maleCount],
          });
          maleCount++;
        }
      }
      
      if (maleCount >= 5 && femaleCount >= 5) break;
    }
    
    // Fallback: If the device doesn't use "male"/"female" in its internal voice names,
    // we use gender-neutral names so they are accurate regardless of the actual voice gender.
    if (finalVoices.isEmpty) {
      int idx = 0;
      final neutralNames = ['Taylor', 'Jordan', 'Casey', 'Riley', 'Morgan', 'Avery', 'Quinn', 'Peyton', 'Cameron', 'Skyler'];
      for (var v in voices) {
        final map = Map<String, String>.from(v as Map);
        final locale = map['locale']?.toLowerCase() ?? '';
        if (locale.startsWith('en')) {
          finalVoices.add({
            'name': map['name'] ?? '',
            'locale': map['locale'] ?? '',
            'displayName': neutralNames[idx],
          });
          idx++;
          if (idx >= 10) break;
        }
      }
    }

    return finalVoices;
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
