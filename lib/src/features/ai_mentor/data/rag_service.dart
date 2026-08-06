import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lg_interactive_onboarding/src/features/ai_mentor/data/offline_embedding_service.dart';

class VectorChunk {
  final String text;
  final Float32List vector;
  
  VectorChunk({required this.text, required this.vector});
}

/// Service to handle local Semantic Vector Retrieval-Augmented Generation (RAG).
class RagService {
  final Ref _ref;
  final List<VectorChunk> _chunks = [];
  bool _isInitialized = false;

  RagService(this._ref);

  /// Loads the pre-computed Wiki embeddings from assets in a background isolate.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _ref.read(offlineEmbeddingServiceProvider).init();
      
      // Offload BOTH the file loading and JSON parsing to a background isolate.
      // Passing a huge string across isolate boundaries doubles its memory footprint.
      // Using RootIsolateToken allows the background isolate to read assets directly!
      final rootToken = RootIsolateToken.instance!;
      final parsedChunks = await compute(_loadAndParseEmbeddings, rootToken);
      
      _chunks.clear();
      _chunks.addAll(parsedChunks);

      _isInitialized = true;
      debugPrint('RagService initialized with ${_chunks.length} vector chunks.');
    } catch (e) {
      debugPrint('RagService failed to initialize: $e');
    }
  }

  // Top-level function for isolate spawning.
  static Future<List<VectorChunk>> _loadAndParseEmbeddings(RootIsolateToken token) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    final jsonString = await rootBundle.loadString('assets/knowledge/lg_wiki_embeddings.json');
    final List<dynamic> data = jsonDecode(jsonString);
    final List<VectorChunk> result = [];
    
    for (final item in data) {
      final text = item['text'] as String?;
      final embeddingList = item['embedding'] as List<dynamic>?;
      
      if (text != null && embeddingList != null) {
        // Use Float32List to drastically reduce memory footprint compared to standard List<double>
        final vector = Float32List(embeddingList.length);
        for (int i = 0; i < embeddingList.length; i++) {
          vector[i] = (embeddingList[i] as num).toDouble();
        }
        result.add(VectorChunk(text: text, vector: vector));
      }
    }
    return result;
  }

  /// Calculates cosine similarity between two vectors.
  double _cosineSimilarity(List<double> a, Float32List b) {
    if (a.length != b.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Semantically searches the chunks for the top 3 most relevant results.
  Future<List<String>> search(String prompt) async {
    if (!_isInitialized || _chunks.isEmpty || prompt.trim().isEmpty) {
      return [];
    }

    final promptEmbedding = await _ref.read(offlineEmbeddingServiceProvider).getEmbedding(prompt.trim());
    if (promptEmbedding.isEmpty) return [];

      // Score all chunks
      final scores = <Map<String, dynamic>>[];
      for (final chunk in _chunks) {
        final score = _cosineSimilarity(promptEmbedding, chunk.vector);
        scores.add({'text': chunk.text, 'score': score});
      }

      // Sort descending
      scores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Return top 3
    return scores.take(3).map((e) => e['text'] as String).toList();
  }
}

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(ref);
});
