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

  // KML Playground
  static const _playgroundOpenedKey = 'analytics_playground_opened';
  static const _playgroundKmlPushedKey = 'analytics_playground_kml_pushed';

  // AI Mentor
  static const _mentorOpenedKey = 'analytics_mentor_opened';
  static const _mentorQuestionAskedKey = 'analytics_mentor_question_asked';

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

  // ─── KML Playground ───────────────────────────────────────────────────────

  /// Records that the user opened the KML Playground.
  Future<void> recordPlaygroundOpened() async {
    await _prefs.setBool(_playgroundOpenedKey, true);
  }

  /// Returns true if the KML Playground has been opened.
  bool hasOpenedPlayground() {
    return _prefs.getBool(_playgroundOpenedKey) ?? false;
  }

  /// Records that the user pushed KML from the Playground.
  Future<void> recordPlaygroundKmlPushed() async {
    await _prefs.setBool(_playgroundKmlPushedKey, true);
  }

  /// Returns true if the user pushed KML from the Playground.
  bool hasPushedPlaygroundKml() {
    return _prefs.getBool(_playgroundKmlPushedKey) ?? false;
  }

  // ─── AI Mentor ────────────────────────────────────────────────────────────

  /// Records that the user opened the AI Mentor screen.
  Future<void> recordMentorOpened() async {
    await _prefs.setBool(_mentorOpenedKey, true);
  }

  /// Returns true if the AI Mentor screen has been opened.
  bool hasOpenedMentor() {
    return _prefs.getBool(_mentorOpenedKey) ?? false;
  }

  /// Records that the user asked a question to the AI Mentor.
  Future<void> recordMentorQuestionAsked() async {
    await _prefs.setBool(_mentorQuestionAskedKey, true);
  }

  /// Returns true if the user asked a question to the AI Mentor.
  bool hasAskedMentorQuestion() {
    return _prefs.getBool(_mentorQuestionAskedKey) ?? false;
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
