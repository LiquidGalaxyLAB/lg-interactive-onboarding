import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-speech service for voice narration throughout the app.
///
/// Extends [ChangeNotifier] so that widgets watching [ttsServiceProvider]
/// (via [ChangeNotifierProvider]) rebuild when [isEnabled] changes — e.g.
/// to update the mute/unmute icon without requiring a separate state layer.
class TTSService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isEnabled = true;

  TTSService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
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
}

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Singleton TTS service — use [ChangeNotifierProvider] so widgets can
/// reactively watch [TTSService.isEnabled] and [TTSService.isSpeaking].
final ttsServiceProvider = Provider<TTSService>((ref) {
  return TTSService();
});
