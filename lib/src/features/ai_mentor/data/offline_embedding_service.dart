import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class OfflineEmbeddingService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // NOTE: The .tflite model and vocab need to be placed in assets/models/
      // _interpreter = await Interpreter.fromAsset('models/minilm_l6.tflite');
      _isInitialized = true;
      debugPrint('OfflineEmbeddingService initialized (stub)');
    } catch (e) {
      debugPrint('Failed to load embedding model: $e');
    }
  }

  Future<List<double>> getEmbedding(String text) async {
    if (!_isInitialized || _interpreter == null) {
      // Return a dummy embedding for now until the model is provided
      debugPrint('Warning: Offline embedding model not loaded, returning empty vector.');
      return List.filled(384, 0.0); // e.g. 384 for MiniLM
    }

    try {
      // 1. Tokenize text (requires a dart tokenizer for the specific model)
      // 2. Run inference
      // final input = [tokenized_text];
      // final output = List.filled(1 * 384, 0.0).reshape([1, 384]);
      // _interpreter?.run(input, output);
      // return (output[0] as List<dynamic>).map((e) => (e as num).toDouble()).toList();
      
      // Stub
      return List.filled(384, 0.0);
    } catch (e) {
      debugPrint('Embedding generation failed: $e');
      return [];
    }
  }
}

final offlineEmbeddingServiceProvider = Provider<OfflineEmbeddingService>((ref) {
  return OfflineEmbeddingService();
});
