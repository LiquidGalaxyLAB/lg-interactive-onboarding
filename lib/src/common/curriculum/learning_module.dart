/// Curriculum Engine – Core data models.
///
/// These types are the shared contract between the Curriculum Engine and
/// every feature module that exposes learning content. Feature modules can
/// create [LearningModule] instances independently and register them via
/// [CurriculumRegistry]; no changes to this file are needed when new
/// features are added.
library;

// ─── Module Status ──────────────────────────────────────────────────────────

/// Lifecycle state of a [LearningModule].
enum ModuleStatus {
  /// Prerequisite module has not been completed yet.
  locked,

  /// All prerequisites met; the user has not started this module.
  available,

  /// The user has started but not yet finished this module.
  inProgress,

  /// The user has successfully completed all steps.
  completed,
}

// ─── Module Step ────────────────────────────────────────────────────────────

/// A single verifiable step inside a [LearningModule].
class ModuleStep {
  /// Stable identifier for this step (used for logging / analytics).
  final String id;

  /// Instruction text displayed in the guided-mode overlay.
  final String instruction;

  /// Optional: the [GlobalKey] key-string of the widget to spotlight.
  ///
  /// If non-null, the overlay punches a hole around that widget.
  final String? targetWidgetKey;

  /// Key into [verificationCheckProvider] that maps this step to a
  /// provider-reading check function.
  ///
  /// The [GuidedModeController] polls the corresponding check every second.
  /// If no mapping exists for this key, the step falls back to manual
  /// confirmation.
  final String verificationKey;

  /// When `true`, the guided overlay shows a "Done — Continue" button
  /// instead of polling a provider. Use this for navigation-only steps
  /// (e.g., "Open the Settings tab") that cannot be auto-detected.
  final bool requiresManualConfirmation;

  ModuleStep({
    required this.id,
    required this.instruction,
    required this.verificationKey,
    this.targetWidgetKey,
    this.requiresManualConfirmation = false,
  });
}

// ─── Learning Module ─────────────────────────────────────────────────────────

/// A self-contained learning unit.
///
/// The [status] field is mutable so that [curriculumModulesProvider] can
/// stamp the live status onto module instances before handing them to the UI,
/// without requiring an immutable copyWith pattern for a display-only field.
class LearningModule {
  /// Stable identifier (persisted in SharedPreferences).
  final String id;

  final String title;
  final String description;
  final Duration estimatedTime;

  /// Route of the screen the user needs to reach for this module.
  ///
  /// Used by [GuidedModeController] to open the target screen automatically.
  final String targetFeatureRoute;

  /// Ordered list of verifiable steps.
  final List<ModuleStep> steps;

  /// Prerequisite module IDs that must be [ModuleStatus.completed] before
  /// this module becomes [ModuleStatus.available].
  ///
  /// Leave empty for no prerequisites (always available).
  final List<String> prerequisites;

  /// Live status — set by [curriculumModulesProvider] before the list is
  /// handed to the UI. Not persisted here; persistence is in [CurriculumRepository].
  ModuleStatus status;

  LearningModule({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedTime,
    required this.targetFeatureRoute,
    required this.steps,
    this.prerequisites = const [],
    this.status = ModuleStatus.locked,
  });
}

// ─── App Routes (typed constants) ───────────────────────────────────────────

/// Named route constants shared between the shell and feature modules.
abstract final class AppRoutes {
  static const settings = '/settings';
  static const dashboard = '/dashboard';
  static const modelBuilder = '/model-builder';
  static const architectureExplorer = '/architecture-explorer';
  static const learn = '/learn';
}
