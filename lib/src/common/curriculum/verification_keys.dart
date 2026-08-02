/// Shared constants for verification keys in the Curriculum Engine.
///
/// Prevents typos between `curriculum_providers.dart` and `verification_providers.dart`.
abstract final class VerificationKeys {
  // ─── Shared / Fallback ──────────────────────────────────────────────────────
  static const manualNavigation = 'manual_navigation';

  // ─── Module 1: Connect to Liquid Galaxy ───────────────────────────────────
  static const sshConnected = 'ssh_connected';

  // ─── Module 2: Upload Your First 3D Model ─────────────────────────────────
  static const modelImported = 'model_imported';
  static const modelPlaced = 'model_placed';
  static const modelPushed = 'model_pushed';

  // ─── Module 3: Understanding KML ──────────────────────────────────────────
  static const kmlPreviewViewed = 'kml_preview_viewed';
  static const kmlReadPause = 'kml_read_pause';

  // ─── Module 4: KML Playground ─────────────────────────────────────────────
  static const playgroundOpened = 'playground_opened';
  static const playgroundKmlPushed = 'playground_kml_pushed';

  // ─── Module 5: AI Mentor ──────────────────────────────────────────────────
  static const mentorOpened = 'mentor_opened';
  static const mentorQuestionAsked = 'mentor_question_asked';

  // ─── Module 6: SSH & LG Architecture ──────────────────────────────────────
  static const diagramViewed = 'diagram_viewed';
  static const diagramHotspotTapped = 'diagram_hotspot_tapped';

  // ─── Module 7: Deep Clean & Troubleshooting ───────────────────────────────
  static const deepCleanConfirmed = 'deep_clean_confirmed';
}
