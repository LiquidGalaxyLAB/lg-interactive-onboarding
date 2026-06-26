import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/learning_module.dart';
import 'package:lg_interactive_onboarding/src/features/curriculum_engine/data/curriculum_repository.dart';


// ─── Curriculum Registry ──────────────────────────────────────────────────────
//
// MODULARITY NOTE:
// To add a new module from a future feature (e.g., Timeline Editor), simply
// add an entry to the list returned by [_buildModules]. No other file needs
// to change. The [CurriculumStatusNotifier] automatically handles lock/unlock
// based on the [LearningModule.prerequisites] field.

/// Constructs the ordered list of all learning modules with their
/// verification keys.
///
/// This is the **only place** module content is defined. Each [ModuleStep]
/// declares a `verificationKey` that maps to a check in
/// [verificationCheckProvider]. Steps that cannot be auto-detected set
/// `requiresManualConfirmation: true`.
List<LearningModule> _buildModules(Ref ref) {
  return [
    // ── Module 1: Connect to Liquid Galaxy ──────────────────────────────────
    LearningModule(
      id: 'connect_lg',
      title: 'Connect to Liquid Galaxy',
      description:
          'Learn how to configure SSH credentials and establish a connection '
          'to your Liquid Galaxy rig.',
      estimatedTime: const Duration(minutes: 3),
      targetFeatureRoute: AppRoutes.settings,
      prerequisites: [], // first module — always available
      steps: [
        ModuleStep(
          id: 'open_settings',
          instruction:
              'Open the Settings tab and fill in your Liquid Galaxy '
              'host address, port, username, and password.',
          verificationKey: 'manual_navigation',
          requiresManualConfirmation: true,
        ),
        ModuleStep(
          id: 'tap_connect',
          instruction:
              'Tap the "Save & Connect" button. The app will attempt to '
              'reach your LG master node via SSH.',
          targetWidgetKey: 'connectButton',
          verificationKey: 'ssh_connected',
        ),
      ],
    ),

    // ── Module 2: Upload Your First 3D Model ────────────────────────────────
    LearningModule(
      id: 'upload_3d_model',
      title: 'Upload Your First 3D Model',
      description:
          'Import a COLLADA or glTF model, place it on the map, configure '
          'orientation, then push it live to Liquid Galaxy.',
      estimatedTime: const Duration(minutes: 8),
      targetFeatureRoute: AppRoutes.modelBuilder,
      prerequisites: ['connect_lg'],
      steps: [
        ModuleStep(
          id: 'import_model',
          instruction:
              'Tap "Import Model" or choose a bundled sample model '
              'to get started. Accepted formats: .dae, .obj, .glb, .gltf, .kmz.',
          verificationKey: 'model_imported',
        ),
        ModuleStep(
          id: 'place_on_map',
          instruction:
              'Long-press anywhere on the map to drop a placement pin '
              'for your model.',
          verificationKey: 'model_placed',
        ),
        ModuleStep(
          id: 'push_model',
          instruction:
              'Tap the "Push to LG" button to upload the model and '
              'generate the KML. This may take a moment.',
          targetWidgetKey: 'pushToLGButton',
          verificationKey: 'model_pushed',
        ),
      ],
    ),

    // ── Module 3: Understanding KML – Model Wrapper ─────────────────────────
    LearningModule(
      id: 'understand_kml',
      title: 'Understanding KML – Model Wrapper',
      description:
          'Explore the generated KML that wraps your 3D model. '
          'Learn the structure of a <Model> KML block.',
      estimatedTime: const Duration(minutes: 4),
      targetFeatureRoute: AppRoutes.modelBuilder,
      prerequisites: ['upload_3d_model'],
      steps: [
        ModuleStep(
          id: 'view_kml_preview',
          instruction:
              'Expand the "KML Preview" panel at the bottom of the '
              '3D Model Builder screen to see the generated XML.',
          targetWidgetKey: 'kmlPreviewExpand',
          verificationKey: 'kml_preview_viewed',
        ),
        ModuleStep(
          id: 'read_kml',
          instruction:
              'Read through the <Model> block. Notice the <Location>, '
              '<Orientation>, and <Scale> elements — these map directly to '
              'the sliders you configured.',
          verificationKey: 'kml_read_pause',
          requiresManualConfirmation: true,
        ),
      ],
    ),

    // ── Module 6: SSH & LG Architecture ─────────────────────────────────────
    LearningModule(
      id: 'ssh_architecture',
      title: 'SSH & LG Architecture',
      description:
          'Explore interactive diagrams that show how the Liquid Galaxy '
          'master-slave topology, ViewSync, SSH, and KML propagation work.',
      estimatedTime: const Duration(minutes: 5),
      targetFeatureRoute: AppRoutes.architectureExplorer,
      prerequisites: ['understand_kml'],
      steps: [
        ModuleStep(
          id: 'open_explorer',
          instruction:
              'Open the Architecture Explorer. You can find it in the '
              '"Learn" tab or by tapping the ⓘ icon in any screen\'s app bar.',
          verificationKey: 'diagram_viewed',
        ),
        ModuleStep(
          id: 'tap_hotspot',
          instruction:
              'Tap on at least one highlighted component in a diagram '
              'to see a detailed explanation.',
          verificationKey: 'diagram_hotspot_tapped',
        ),
      ],
    ),

    // ── Module 7: Deep Clean & Troubleshooting ──────────────────────────────
    LearningModule(
      id: 'deep_clean',
      title: 'Deep Clean & Troubleshooting',
      description:
          'Learn how to reset the Liquid Galaxy rig by removing all '
          'cached model files and resetting the master KML.',
      estimatedTime: const Duration(minutes: 3),
      targetFeatureRoute: AppRoutes.dashboard,
      prerequisites: ['ssh_architecture'],
      steps: [
        ModuleStep(
          id: 'find_deep_clean',
          instruction:
              'On the Dashboard, scroll down to the "Maintenance" section '
              'and locate the "Deep Clean" card.',
          verificationKey: 'manual_navigation',
          requiresManualConfirmation: true,
        ),
        ModuleStep(
          id: 'confirm_deep_clean',
          instruction:
              'Tap "Deep Clean" and confirm the dialog. This will wipe '
              'all model files from the LG rig.',
          targetWidgetKey: 'deepCleanButton',
          verificationKey: 'deep_clean_confirmed',
        ),
      ],
    ),
  ];
}

// ─── Status Notifier ──────────────────────────────────────────────────────────

/// Manages the live status of all modules, applying lock/unlock logic.
///
/// Lock logic: a module is [ModuleStatus.available] when all its
/// [LearningModule.prerequisites] are [ModuleStatus.completed]; otherwise
/// [ModuleStatus.locked]. Persisted statuses from [CurriculumRepository]
/// override defaults.
class CurriculumStatusNotifier
    extends Notifier<Map<String, ModuleStatus>> {
  late List<LearningModule> _modules;

  @override
  Map<String, ModuleStatus> build() {
    _modules = _buildModules(ref);
    final repo = ref.read(curriculumRepositoryProvider);
    final ids = _modules.map((m) => m.id).toList();
    final saved = repo.getAllStatuses(ids);
    return _applyLockLogic(saved);
  }

  /// Returns the current status for [moduleId].
  ModuleStatus statusOf(String moduleId) {
    return state[moduleId] ?? ModuleStatus.available;
  }

  /// Marks [moduleId] as [status] and re-evaluates downstream lock states.
  Future<void> setStatus(String moduleId, ModuleStatus status) async {
    final repo = ref.read(curriculumRepositoryProvider);
    await repo.setModuleStatus(moduleId, status);
    final updated = Map<String, ModuleStatus>.from(state)
      ..[moduleId] = status;
    state = _applyLockLogic(updated);
  }

  /// Resets all progress (dev helper).
  Future<void> resetAll() async {
    final repo = ref.read(curriculumRepositoryProvider);
    final ids = _modules.map((m) => m.id).toList();
    await repo.resetAll(ids);
    state = _applyLockLogic({});
  }

  Map<String, ModuleStatus> _applyLockLogic(Map<String, ModuleStatus> base) {
    final result = Map<String, ModuleStatus>.from(base);

    for (final module in _modules) {
      final current = result[module.id] ?? ModuleStatus.available;

      // Already completed — never re-lock.
      if (current == ModuleStatus.completed) continue;

      // Since modules are optional, everything is available by default
      result[module.id] = ModuleStatus.available;
    }

    return result;
  }
}

final curriculumStatusProvider =
    NotifierProvider<CurriculumStatusNotifier, Map<String, ModuleStatus>>(
  CurriculumStatusNotifier.new,
);

// ─── Derived: ordered module list with live status ────────────────────────────

/// Ordered list of [LearningModule]s with their current [ModuleStatus]
/// baked in as a mutable field.
///
/// Widgets should watch this provider to rebuild when any status changes.
final curriculumModulesProvider = Provider<List<LearningModule>>((ref) {
  final statusMap = ref.watch(curriculumStatusProvider);
  // Build fresh so autoVerify closures capture fresh ref.
  return _buildModules(ref).map((module) {
    module.status = statusMap[module.id] ?? ModuleStatus.locked;
    return module;
  }).toList();
});

// ─── Completion progress ──────────────────────────────────────────────────────

/// Number of completed modules.
final completedModuleCountProvider = Provider<int>((ref) {
  final statuses = ref.watch(curriculumStatusProvider);
  return statuses.values.where((s) => s == ModuleStatus.completed).length;
});

/// Total module count.
final totalModuleCountProvider = Provider<int>((ref) {
  return ref.watch(curriculumModulesProvider).length;
});
