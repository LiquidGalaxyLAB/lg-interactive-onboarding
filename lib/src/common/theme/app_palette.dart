import 'package:flutter/material.dart';

/// Shared Material Design 3 colour palette used across all features.
///
/// Colors are derived from Google's official Material Design 3 colour system
/// using Google Blue (#1A73E8) as the primary seed. Semantic roles match
/// the M3 spec: error, success, warning, outline, surface, onSurface.
///
/// Property names are intentionally preserved from the previous palette so
/// all existing call-sites compile without modification.
class AppPalette {
  AppPalette._();

  // ── Primary ────────────────────────────────────────────────────────────────
  /// Google Blue — primary brand colour (same as Google Workspace).
  static const primary = Color(0xFF1A73E8);

  /// Tonal primary container (light theme use).
  static const primaryContainer = Color(0xFFD3E3FD);

  // ── Semantic: Error (replaces terracotta / deepCleanRed) ───────────────────
  /// M3 Error Red — light theme.
  static const terracotta    = Color(0xFFB3261E);

  /// M3 Error Red — same as terracotta, alias kept for deep-clean card.
  static const deepCleanRed  = Color(0xFFB3261E);

  // ── Semantic: Success (replaces sage) ──────────────────────────────────────
  /// M3 Success Green — used for connection status, positive feedback.
  static const sage          = Color(0xFF1E8E3E);

  // ── Semantic: Warning (replaces warmAmber) ─────────────────────────────────
  /// M3 Warning Amber — used for caution states.
  static const warmAmber     = Color(0xFFE37400);

  // ── Secondary (replaces dustyBlue) ────────────────────────────────────────
  /// Google Blue-Grey — secondary actions and info highlights.
  static const dustyBlue     = Color(0xFF4A6785);

  // ── Neutral (replaces warmGrey) ────────────────────────────────────────────
  /// M3 Outline colour — used for dividers, placeholders, secondary text.
  static const warmGrey      = Color(0xFF747775);

  // ── Surface (replaces parchment) ───────────────────────────────────────────
  /// Google's canonical light surface — used as scaffold/appbar background.
  static const parchment     = Color(0xFFF8F9FA);

  // ── On-Surface (replaces inkDark) ──────────────────────────────────────────
  /// M3 On-Surface — primary text colour on light backgrounds.
  static const inkDark       = Color(0xFF1F1F1F);

  // ── Feature accent (replaces modelBuilderIndigo) ───────────────────────────
  /// Google Blue used as the 3-D Model Builder feature accent.
  static const modelBuilderIndigo = Color(0xFF1A73E8);

  /// Teal accent for the KML Playground feature card.
  static const kmlPlaygroundTeal = Color(0xFF009688);

  // ── Dark-theme semantic overrides (for convenience references) ─────────────
  /// Success green on dark backgrounds.
  static const successDark   = Color(0xFF72DD87);

  /// Error red on dark backgrounds.
  static const errorDark     = Color(0xFFF2B8B5);

  /// Warning amber on dark backgrounds.
  static const warningDark   = Color(0xFFFFB951);
}
