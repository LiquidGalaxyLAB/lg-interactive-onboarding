import 'package:flutter/material.dart';

/// Shared colour palette used across all features.
///
/// Centralised here so that any widget (dashboard, settings, etc.)
/// can import a single, canonical source of truth for colours.
class AppPalette {
  AppPalette._();

  static const terracotta = Color(0xFFC0392B);
  static const warmAmber = Color(0xFFD4A574);
  static const sage = Color(0xFF7FB069);
  static const dustyBlue = Color(0xFF5B8BA0);
  static const warmGrey = Color(0xFF8E8D8A);
  static const parchment = Color(0xFFF5F0EB);
  static const inkDark = Color(0xFF2C2C2C);
  static const deepCleanRed = Color(0xFFB03A2E);
  static const modelBuilderIndigo = Color(0xFF6C5CE7);
}
