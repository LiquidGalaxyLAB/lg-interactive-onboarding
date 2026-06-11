import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Lightweight analytics service backed by SharedPreferences.
///
/// Tracks user interactions relevant to auto-verification (diagram views,
/// screen opens, etc.) without any third-party dependency.
///
/// ### Adding new tracked events
/// Add a new `record*` / `get*` method pair. The key convention is:
/// `analytics_<category>_<id>`.
class AnalyticsService {
  final SharedPreferences _prefs;

  AnalyticsService(this._prefs);

  // ─── Keys ─────────────────────────────────────────────────────────────────

  static String _diagramKey(String diagramId) =>
      'analytics_diagram_views_$diagramId';
  static const _kmlPreviewKey = 'analytics_kml_preview_opened';
  static const _deepCleanKey = 'analytics_deep_clean_confirmed';

  // ─── Diagram Views ────────────────────────────────────────────────────────

  /// Increments the view count for [diagramId].
  Future<void> recordDiagramView(String diagramId) async {
    final key = _diagramKey(diagramId);
    final current = _prefs.getInt(key) ?? 0;
    await _prefs.setInt(key, current + 1);
  }

  /// Returns the number of times [diagramId] has been viewed.
  int getDiagramViewCount(String diagramId) {
    return _prefs.getInt(_diagramKey(diagramId)) ?? 0;
  }

  /// Returns the total number of distinct diagram views across all diagrams.
  int getTotalDiagramViews() {
    return _prefs
        .getKeys()
        .where((k) => k.startsWith('analytics_diagram_views_'))
        .fold(0, (sum, k) => sum + (_prefs.getInt(k) ?? 0));
  }

  // ─── KML Preview ──────────────────────────────────────────────────────────

  /// Records that the user opened the KML preview panel.
  Future<void> recordKmlPreviewOpened() async {
    await _prefs.setBool(_kmlPreviewKey, true);
  }

  /// Returns true if the KML preview has been opened at least once.
  bool hasOpenedKmlPreview() {
    return _prefs.getBool(_kmlPreviewKey) ?? false;
  }

  // ─── Deep Clean ───────────────────────────────────────────────────────────

  /// Records that the user confirmed a deep clean operation.
  Future<void> recordDeepCleanConfirmed() async {
    await _prefs.setBool(_deepCleanKey, true);
  }

  /// Returns true if the deep clean has been confirmed at least once.
  bool hasConfirmedDeepClean() {
    return _prefs.getBool(_deepCleanKey) ?? false;
  }

  // ─── Reset (for testing / dev) ────────────────────────────────────────────

  /// Clears all analytics data. Useful during development.
  Future<void> resetAll() async {
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith('analytics_'))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AnalyticsService(prefs);
});
