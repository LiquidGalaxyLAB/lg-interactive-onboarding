import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learning_module.dart';

import 'package:lg_interactive_onboarding/src/features/curriculum_engine/providers/verification_providers.dart';

// ─── Guided Mode State ───────────────────────────────────────────────────────

/// Immutable snapshot of the current guided-mode session.
class GuidedModeState {
  final LearningModule? activeModule;
  final int currentStepIndex;
  final GuidedModePhase phase;
  final String? phaseMessage;

  const GuidedModeState({
    this.activeModule,
    this.currentStepIndex = 0,
    this.phase = GuidedModePhase.idle,
    this.phaseMessage,
  });

  bool get isActive => phase != GuidedModePhase.idle;

  /// Whether the current step requires manual confirmation (no auto-polling).
  bool get isManualStep => currentStep?.requiresManualConfirmation ?? false;

  ModuleStep? get currentStep {
    final mod = activeModule;
    if (mod == null) return null;
    if (currentStepIndex >= mod.steps.length) return null;
    return mod.steps[currentStepIndex];
  }

  int get totalSteps => activeModule?.steps.length ?? 0;

  GuidedModeState copyWith({
    LearningModule? activeModule,
    int? currentStepIndex,
    GuidedModePhase? phase,
    String? phaseMessage,
  }) {
    return GuidedModeState(
      activeModule: activeModule ?? this.activeModule,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      phase: phase ?? this.phase,
      phaseMessage: phaseMessage ?? this.phaseMessage,
    );
  }
}

/// Current phase of the guided-mode session.
enum GuidedModePhase {
  /// No module is active.
  idle,

  /// A module is running and a step is being executed by the user.
  running,

  /// The auto-verify predicate returned true; advancing to next step.
  advancing,

  /// All steps are done; showing the completion screen.
  completed,

  /// The user manually cancelled the session.
  cancelled,
}

// ─── GuidedModeController ────────────────────────────────────────────────────

/// Riverpod [Notifier] that manages the lifecycle of a guided tutorial session.
///
/// ### Modularity contract
/// Any feature that adds a [LearningModule] to the registry automatically
/// works with this controller — no changes here are required.
///
/// ### Overlay strategy
/// The controller uses an [OverlayEntry] injected into the root [Navigator]'s
/// overlay so that the overlay persists across route pushes within the shell.
///
/// ### Verification strategy
/// After the user begins a step the controller polls [ModuleStep.autoVerify]
/// every [_pollInterval] until:
///   - the predicate returns `true` → advance to next step, or
///   - [_maxPollDuration] elapses → show timeout message.
class GuidedModeController extends Notifier<GuidedModeState> {
  static const _pollInterval = Duration(seconds: 1);
  static const _maxPollDuration = Duration(seconds: 90);

  OverlayEntry? _overlayEntry;
  Timer? _pollTimer;
  DateTime? _pollStart;

  // Root navigator key injected by main.dart for overlay access.
  GlobalKey<NavigatorState>? navigatorKey;

  @override
  GuidedModeState build() => const GuidedModeState();

  // ─── Spotlight Keys ─────────────────────────────────────────────────────

  static final Map<String, GlobalKey> _spotlightKeys = {};

  /// Retrieves or creates a [GlobalKey] used to track a specific widget
  /// for the guided mode spotlight.
  static GlobalKey spotlightKey(String id) {
    return _spotlightKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'spotlight_$id'));
  }

  // ─── Public API ─────────────────────────────────────────────────────────

  /// Begins a guided session for [module].
  ///
  /// If a session is already active it is cancelled first.
  void startModule(LearningModule module) {
    _cancelPoll();
    _removeOverlay();

    state = GuidedModeState(
      activeModule: module,
      currentStepIndex: 0,
      phase: GuidedModePhase.running,
    );

    _insertOverlay();
    // Only poll if the first step supports auto-verification.
    if (!state.isManualStep) {
      _beginPolling();
    }
  }

  /// Manually skips the current step (does not mark it verified).
  void skipCurrentStep() {
    _cancelPoll();
    _advance();
  }

  /// Manually confirms the current step (used for steps where
  /// [ModuleStep.requiresManualConfirmation] is `true`).
  void manualConfirm() {
    _cancelPoll();
    _advance();
  }

  /// Cancels the active session without marking the module complete.
  void cancelModule() {
    _cancelPoll();
    _removeOverlay();
    state = const GuidedModeState(phase: GuidedModePhase.cancelled);
    // Short delay then reset to idle so UI can show cancellation animation.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (state.phase == GuidedModePhase.cancelled) {
        state = const GuidedModeState();
      }
    });
  }

  /// Called after the completion screen is dismissed.
  void acknowledgeCompletion() {
    state = const GuidedModeState();
  }

  // ─── Internal helpers ────────────────────────────────────────────────────

  void _beginPolling() {
    _pollStart = DateTime.now();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    final step = state.currentStep;
    if (step == null) return;

    // Manual-confirm steps are never auto-polled.
    if (step.requiresManualConfirmation) return;

    // Timeout guard
    final elapsed = DateTime.now().difference(_pollStart!);
    if (elapsed > _maxPollDuration) {
      _cancelPoll();
      state = state.copyWith(
        phaseMessage:
            'Step is taking longer than expected. You can skip or retry.',
      );
      return;
    }

    try {
      final checkMap = ref.read(verificationCheckProvider);
      final check = checkMap[step.verificationKey];
      if (check == null) {
        debugPrint(
          'GuidedModeController: no verification check for '
          'key "${step.verificationKey}"',
        );
        return;
      }
      final done = check(ref);
      if (done) {
        _cancelPoll();
        _advance();
      }
    } catch (e) {
      debugPrint('GuidedModeController: verification error: $e');
    }
  }

  void _advance() {
    final mod = state.activeModule;
    if (mod == null) return;

    final nextIndex = state.currentStepIndex + 1;

    if (nextIndex >= mod.steps.length) {
      // Module complete
      _removeOverlay();
      state = state.copyWith(phase: GuidedModePhase.completed);
    } else {
      state = state.copyWith(
        currentStepIndex: nextIndex,
        phase: GuidedModePhase.running,
        phaseMessage: null,
      );
      // Only poll for auto-verifiable steps.
      final nextStep = mod.steps[nextIndex];
      if (!nextStep.requiresManualConfirmation) {
        _beginPolling();
      }
      _updateOverlay();
    }
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ─── Overlay management ─────────────────────────────────────────────────

  void _insertOverlay() {
    final navKey = navigatorKey;
    if (navKey == null) return;
    final overlay = navKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (_) => _GuidedModeOverlayBridge(controller: this),
    );
    overlay.insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// Thin bridge widget so the overlay can watch provider state reactively.
///
/// This is intentionally minimal — the actual overlay UI lives in
/// `guided_mode_overlay.dart` so it can be styled independently.
class _GuidedModeOverlayBridge extends StatelessWidget {
  final GuidedModeController controller;
  const _GuidedModeOverlayBridge({required this.controller});

  @override
  Widget build(BuildContext context) {
    // The overlay import is done lazily by the presentation layer.
    // This bridge widget is replaced by the real overlay in guided_mode_overlay.dart.
    return const SizedBox.shrink();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final guidedModeControllerProvider =
    NotifierProvider<GuidedModeController, GuidedModeState>(
  GuidedModeController.new,
);
