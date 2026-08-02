// Kept for backward-compat with existing dashboard widgets.
// All new code should import AppPalette directly from:
//   package:lg_interactive_onboarding/src/common/theme/app_palette.dart
import 'package:lg_interactive_onboarding/src/common/theme/app_palette.dart';

/// Thin alias over [AppPalette] so existing `DashboardPalette.xxx` call-sites
/// continue to compile without modification.
class DashboardPalette {
  DashboardPalette._();

  // ── LG Brand Colors ────────────────────────────────────────────────────────
  static const lgRed    = AppPalette.lgRed;
  static const lgBlue   = AppPalette.lgBlue;
  static const lgYellow = AppPalette.lgYellow;
  static const lgGreen  = AppPalette.lgGreen;
  static const lgGradientColors = AppPalette.lgGradientColors;

  // ── Legacy Aliases ─────────────────────────────────────────────────────────
  static const terracotta     = AppPalette.terracotta;
  static const warmAmber      = AppPalette.warmAmber;
  static const sage           = AppPalette.sage;
  static const dustyBlue      = AppPalette.dustyBlue;
  static const warmGrey       = AppPalette.warmGrey;
  static const parchment      = AppPalette.parchment;
  static const inkDark        = AppPalette.inkDark;
  static const deepCleanRed   = AppPalette.deepCleanRed;
  static const modelBuilderIndigo = AppPalette.modelBuilderIndigo;
  static const kmlPlaygroundTeal  = AppPalette.kmlPlaygroundTeal;
}
