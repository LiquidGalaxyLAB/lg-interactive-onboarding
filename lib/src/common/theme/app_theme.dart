import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme following Material 3 design.
///
/// Uses a curated color palette with Inter font for a premium look.
class AppTheme {
  AppTheme._();

  // ─── Color Palette ───────────────────────────────────────────────
  static const _seedColor = Color(0xFF6C5CE7);
  static const _accentColor = Color(0xFF00D2FF);

  // ─── Dark Theme ──────────────────────────────────────────────────
  static final darkTheme = _buildTheme(
    brightness: Brightness.dark,
    scaffold: const Color(0xFF0A0E1A),
    surface: const Color(0xFF141929),
    surfaceVariant: const Color(0xFF1C2236),
    inputFill: const Color(0xFF1E2438),
    textTheme: ThemeData.dark().textTheme,
  );

  // ─── Light Theme ─────────────────────────────────────────────────
  static final lightTheme = _buildTheme(
    brightness: Brightness.light,
    scaffold: const Color(0xFFF5F6FA),
    surface: Colors.white,
    surfaceVariant: const Color(0xFFEEF0F7),
    inputFill: const Color(0xFFF0F2F8),
    textTheme: ThemeData.light().textTheme,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color inputFill,
    required TextTheme textTheme,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
        surface: surface,
        secondary: _accentColor,
      ),
      scaffoldBackgroundColor: scaffold,
      textTheme: GoogleFonts.interTextTheme(textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _seedColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: _seedColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(
            color: _seedColor.withValues(alpha: 0.4),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _seedColor,
        thumbColor: _seedColor,
        overlayColor: _seedColor.withValues(alpha: 0.12),
        inactiveTrackColor:
            isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        thickness: 1,
      ),
    );
  }
}
