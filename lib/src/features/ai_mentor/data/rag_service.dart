import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service to handle local Retrieval-Augmented Generation (RAG) using TF-IDF.
class RagService {
  List<String> _chunks = [];
  List<List<String>> _tokenizedChunks = [];
  final Map<String, double> _idfMap = {};

  bool _isInitialized = false;

  /// Loads the Wiki chunks from assets and precomputes the TF-IDF index.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final jsonString = await rootBundle.loadString('assets/knowledge/lg_wiki_chunks.json');
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> pages = data['pages'] ?? [];
      
      _chunks.clear();
      for (final page in pages) {
        final List<dynamic> pageChunks = page['chunks'] ?? [];
        for (final chunk in pageChunks) {
          final text = chunk['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            _chunks.add(text.trim());
          }
        }
      }

      _buildIndex();
      _isInitialized = true;
      debugPrint('RagService initialized with ${_chunks.length} chunks.');
    } catch (e) {
      debugPrint('RagService failed to initialize: $e');
    }
  }

  void _buildIndex() {
    _tokenizedChunks = _chunks.map((c) => _tokenize(c)).toList();
    final int nDocs = _chunks.length;
    final Map<String, int> docFrequency = {};

    for (final tokens in _tokenizedChunks) {
      final uniqueTokens = tokens.toSet();
      for (final t in uniqueTokens) {
        docFrequency[t] = (docFrequency[t] ?? 0) + 1;
      }
    }

    _idfMap.clear();
    docFrequency.forEach((term, freq) {
      // Standard IDF formula with +1 smoothing
      _idfMap[term] = log((nDocs + 1) / (freq + 1)) + 1;
    });
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();
  }

  /// Searches the local index and returns the top `k` most relevant chunks.
  List<String> search(String query, {int k = 3}) {
    if (!_isInitialized || _chunks.isEmpty) return [];

    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty) return [];

    final List<MapEntry<int, double>> scores = [];

    for (int i = 0; i < _chunks.length; i++) {
      final docTokens = _tokenizedChunks[i];
      if (docTokens.isEmpty) continue;

      double score = 0.0;
      for (final qt in queryTokens) {
        if (!_idfMap.containsKey(qt)) continue;

        // Calculate TF
        int termCount = 0;
        for (final dt in docTokens) {
          if (dt == qt) termCount++;
        }
        
        if (termCount > 0) {
          final tf = termCount / docTokens.length;
          final idf = _idfMap[qt]!;
          score += (tf * idf);
        }
      }
      
      if (score > 0) {
        scores.add(MapEntry(i, score));
      }
    }

    // Sort descending
    scores.sort((a, b) => b.value.compareTo(a.value));

    return scores.take(k).map((e) => _chunks[e.key]).toList();
  }

  // Very basic list of English stop words to ignore
  static const Set<String> _stopWords = {
    'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you', 'your', 'yours', 
    'yourself', 'yourselves', 'he', 'him', 'his', 'himself', 'she', 'her', 'hers', 
    'herself', 'it', 'its', 'itself', 'they', 'them', 'their', 'theirs', 'themselves', 
    'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those', 'am', 'is', 'are', 
    'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'having', 'do', 'does', 
    'did', 'doing', 'a', 'an', 'the', 'and', 'but', 'if', 'or', 'because', 'as', 'until', 
    'while', 'of', 'at', 'by', 'for', 'with', 'about', 'against', 'between', 'into', 
    'through', 'during', 'before', 'after', 'above', 'below', 'to', 'from', 'up', 'down', 
    'in', 'out', 'on', 'off', 'over', 'under', 'again', 'further', 'then', 'once', 'here', 
    'there', 'when', 'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more', 
    'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own', 'same', 'so', 
    'than', 'too', 'very', 's', 't', 'can', 'will', 'just', 'don', 'should', 'now'
  };
}

final ragServiceProvider = Provider<RagService>((ref) {
  final service = RagService();
  // We don't await init() here since Providers should ideally return synchronously.
  // Instead, the app or MentorService can ensure init is called.
  return service;
});
