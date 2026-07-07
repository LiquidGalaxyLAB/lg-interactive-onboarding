import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lg_interactive_onboarding/src/common/curriculum/analytics_service.dart';
import 'package:lg_interactive_onboarding/src/common/ssh/ssh_service.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/model_builder_providers.dart';
import 'package:lg_interactive_onboarding/src/features/model_builder/providers/scene_providers.dart';

// ─── Verification Check Provider ──────────────────────────────────────────────
//
// Central mapping from verification key strings to provider-reading check
// functions. Each curriculum [ModuleStep] declares a `verificationKey` that
// is looked up here by [GuidedModeController] during polling.
//
// ### Adding new checks
// To wire a new curriculum step to a provider, add a new entry to the map
// returned below. No other file needs to change.

/// Signature for a synchronous verification check.
///
/// Reads provider state via [ref] and returns `true` when the step is
/// considered complete.
typedef VerificationCheck = bool Function(Ref ref);

/// Maps verification key strings to provider-reading check functions.
///
/// The [GuidedModeController] polls the function corresponding to the
/// current step's `verificationKey` every second. When it returns `true`,
/// the step auto-advances.
final verificationCheckProvider = Provider<Map<String, VerificationCheck>>((ref) {
  return {
    // ── Module 1: Connect to Liquid Galaxy ─────────────────────────────────
    'ssh_connected': (ref) {
      final ssh = ref.read(sshServiceProvider);
      return ssh.isConnected;
    },

    // ── Module 2: Upload Your First 3D Model ──────────────────────────────
    'model_imported': (ref) {
      final project = ref.read(modelBuilderProvider);
      return project.fileName != null;
    },
    'model_placed': (ref) {
      final project = ref.read(modelBuilderProvider);
      return project.latitude != null && project.longitude != null;
    },
    'model_pushed': (ref) {
      return ref.read(modelPushSuccessProvider);
    },

    // ── Module 3: Understanding KML ───────────────────────────────────────
    'kml_preview_viewed': (ref) {
      final analytics = ref.read(analyticsServiceProvider);
      return analytics.hasOpenedKmlPreview();
    },
    // "Read the KML" step — always true (relies on a 10-second delay in the
    // controller before it starts polling, or the controller can just pass
    // this immediately and let the polling interval cover the delay).
    'kml_read_pause': (_) => true,

    // ── Module 6: SSH & LG Architecture ───────────────────────────────────
    'diagram_viewed': (ref) {
      final analytics = ref.read(analyticsServiceProvider);
      return analytics.getTotalDiagramViews() > 0;
    },
    'diagram_hotspot_tapped': (ref) {
      final analytics = ref.read(analyticsServiceProvider);
      return analytics.getTotalDiagramViews() >= 2;
    },

    // ── Module 7: Deep Clean & Troubleshooting ────────────────────────────
    'deep_clean_confirmed': (ref) {
      final analytics = ref.read(analyticsServiceProvider);
      return analytics.hasConfirmedDeepClean();
    },

    // ── Fallback for navigation-only steps ────────────────────────────────
    // Steps with `requiresManualConfirmation: true` never reach this map,
    // but if one slips through, this ensures it doesn't auto-advance.
    'manual_navigation': (_) => false,
  };
});
