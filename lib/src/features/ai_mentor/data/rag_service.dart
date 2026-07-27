import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:lg_interactive_onboarding/src/common/constants/app_constants.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

class VectorChunk {
  final String text;
  final List<double> vector;
  
  VectorChunk({required this.text, required this.vector});
}

/// Service to handle local Semantic Vector Retrieval-Augmented Generation (RAG).
class RagService {
  final Ref _ref;
  final List<VectorChunk> _chunks = [];
  bool _isInitialized = false;

  RagService(this._ref);

  /// Loads the pre-computed Wiki embeddings from assets.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString('assets/knowledge/lg_wiki_embeddings.json');
      final List<dynamic> data = jsonDecode(jsonString);
      
      _chunks.clear();
      for (final item in data) {
        final text = item['text'] as String?;
        final embeddingList = item['embedding'] as List<dynamic>?;
        
        if (text != null && embeddingList != null) {
          final vector = embeddingList.map((e) => (e as num).toDouble()).toList();
          _chunks.add(VectorChunk(text: text, vector: vector));
        }
      }

      _isInitialized = true;
      debugPrint('RagService initialized with ${_chunks.length} vector chunks.');
    } catch (e) {
      debugPrint('RagService failed to initialize: $e');
    }
  }

  /// Calculates cosine similarity between two vectors.
  double _cosineSimilarity(List<double> a, List<double> b) {
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

    try {
      final apiKey = _ref.read(settingsServiceProvider).geminiApiKey;
      if (apiKey.isEmpty) {
        debugPrint('RagService: No API key available for embeddings.');
        return [];
      }

      // Get embedding for prompt
      final uri = Uri.parse('https://openrouter.ai/api/v1/embeddings');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': AppConstants.openRouterEmbeddingModel,
          'input': [prompt.trim()]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('RagService embedding failed: ${response.body}');
        return [];
      }

      final resData = jsonDecode(response.body);
      final List<dynamic>? data = resData['data'];
      if (data == null || data.isEmpty) return [];
      
      final promptEmbedding = (data[0]['embedding'] as List<dynamic>).map((e) => (e as num).toDouble()).toList();

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
    } catch (e) {
      debugPrint('RagService search error: $e');
      return [];
    }
  }
}

final ragServiceProvider = Provider<RagService>((ref) {
  return RagService(ref);
});
