import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';
import 'package:lg_interactive_onboarding/src/features/settings/data/settings_service.dart';

/// Persists and reads [ModuleStatus] values for each [LearningModule].
///
/// ### Key format
/// `curriculum_progress_<moduleId>` → status name string.
///
/// This class is intentionally thin: it only handles persistence.
/// Lock/unlock logic lives in [CurriculumStatusNotifier] so that it can
/// react to Riverpod state without requiring SharedPreferences knowledge.
class CurriculumRepository {
  final SharedPreferences _prefs;

  CurriculumRepository(this._prefs);

  static String _key(String moduleId) => 'curriculum_progress_$moduleId';

  /// Returns the persisted [ModuleStatus] for [moduleId].
  ///
  /// Defaults to [ModuleStatus.available] if no value has been saved.
  ModuleStatus getModuleStatus(String moduleId) {
    final raw = _prefs.getString(_key(moduleId));
    return _parse(raw);
  }

  /// Persists [status] for [moduleId].
  Future<void> setModuleStatus(String moduleId, ModuleStatus status) async {
    await _prefs.setString(_key(moduleId), status.name);
  }

  /// Returns a snapshot of all persisted statuses as a map.
  Map<String, ModuleStatus> getAllStatuses(List<String> moduleIds) {
    return {
      for (final id in moduleIds) id: getModuleStatus(id),
    };
  }

  /// Resets all curriculum progress (useful for development / testing).
  Future<void> resetAll(List<String> moduleIds) async {
    for (final id in moduleIds) {
      await _prefs.remove(_key(id));
    }
  }

  ModuleStatus _parse(String? raw) {
    return ModuleStatus.values.firstWhere(
      (s) => s.name == raw,
      orElse: () => ModuleStatus.available,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CurriculumRepository(prefs);
});
