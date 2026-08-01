import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// A service to handle real-time Speech-to-Text (STT) transcription.
class SttService extends ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _isAvailable = false;

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  bool get isAvailable => _isAvailable;

  /// Initializes the speech recognizer and requests permissions.
  Future<void> init() async {
    _isAvailable = await _speechToText.initialize(
      onError: (e) => debugPrint('STT Error: $e'),
      onStatus: (s) {
        if (s == 'notListening' || s == 'done') {
          _isListening = false;
          notifyListeners();
        }
      },
    );
    notifyListeners();
  }

  /// Starts listening to the microphone and streams the result back.
  void startListening(Function(String) onResult) {
    if (!_isAvailable) {
      init().then((_) {
        if (_isAvailable) _start(onResult);
      });
      return;
    }
    _start(onResult);
  }

  void _start(Function(String) onResult) {
    _isListening = true;
    _recognizedText = '';
    _speechToText.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        onResult(_recognizedText);
        notifyListeners();
      },
    );
    notifyListeners();
  }

  /// Stops listening.
  void stopListening() {
    _speechToText.stop();
    _isListening = false;
    notifyListeners();
  }
}

final sttServiceProvider = Provider<SttService>((ref) {
  final service = SttService();
  service.init();
  return service;
});
