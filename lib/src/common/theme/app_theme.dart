import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme — Material Design 3, Google Blue seed.
///
/// Primary seed: #1A73E8 (Google Blue — identical to Google Workspace apps).
/// The M3 [ColorScheme.fromSeed] engine derives every tonal role automatically.
///
/// Light theme  → crisp white surfaces, #F8F9FA scaffold (Google's canonical bg)
/// Dark theme   → #131314 surface (near-black, avoids blue tint)
class AppTheme {
  AppTheme._();

  // ── Seed & fixed colours ───────────────────────────────────────────────────
  /// Google Blue — generates the full M3 tonal palette.
  static const _seedColor    = Color(0xFF1A73E8);

  /// On-primary text / icon (always white on blue).
  static const _onPrimary    = Color(0xFFFFFFFF);

  // ── Light surface stack ────────────────────────────────────────────────────
  static const _lightScaffold       = Color(0xFFF8F9FA); // Google's bg
  static const _lightSurface        = Color(0xFFFFFFFF);
  static const _lightSurfaceVariant = Color(0xFFE8EAED); // M3 surfaceVariant
  static const _lightInputFill      = Color(0xFFF1F3F4); // Google search-box bg

  // ── Dark surface stack ─────────────────────────────────────────────────────
  static const _darkScaffold        = Color(0xFF131314); // near-black
  static const _darkSurface         = Color(0xFF1E1E20); // M3 surface container
  static const _darkSurfaceVariant  = Color(0xFF2A2A2D); // elevated container
  static const _darkInputFill       = Color(0xFF28282B);

  // ── Public theme objects ───────────────────────────────────────────────────
  static final lightTheme = _buildTheme(
    brightness: Brightness.light,
    scaffold: _lightScaffold,
    surface: _lightSurface,
    surfaceVariant: _lightSurfaceVariant,
    inputFill: _lightInputFill,
    textTheme: ThemeData.light().textTheme,
  );

  static final darkTheme = _buildTheme(
    brightness: Brightness.dark,
    scaffold: _darkScaffold,
    surface: _darkSurface,
    surfaceVariant: _darkSurfaceVariant,
    inputFill: _darkInputFill,
    textTheme: ThemeData.dark().textTheme,
  );

  // ── Builder ────────────────────────────────────────────────────────────────
  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color surfaceVariant,
    required Color inputFill,
    required TextTheme textTheme,
  }) {
    final isDark = brightness == Brightness.dark;

    // M3 tonal color scheme derived from the seed.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      surface: surface,
    );

    // ── On-surface text colours ──────────────────────────────────────────────
    final onSurface       = isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F);
    final onSurfaceMid    = isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368);
    final onSurfaceFaint  = isDark ? const Color(0xFF5F6368) : const Color(0xFFADB5BD);

    // ── Status colours (M3-spec) ─────────────────────────────────────────────
    final errorColor      = isDark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E);

    // ── System overlay ───────────────────────────────────────────────────────
    final systemUiStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _darkSurface,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _lightSurface,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffold,

      // ── Typography ─────────────────────────────────────────────────────────
      textTheme: GoogleFonts.interTextTheme(textTheme).copyWith(
        // M3 display / headline sizes with tighter tracking
        displayLarge:  GoogleFonts.inter(fontWeight: FontWeight.w400, letterSpacing: -0.25),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.25),
        titleLarge:    GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: -0.15),
        titleMedium:   GoogleFonts.inter(fontWeight: FontWeight.w500),
        labelLarge:    GoogleFonts.inter(fontWeight: FontWeight.w600, letterSpacing: 0.1),
        bodyMedium:    GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodySmall:     GoogleFonts.inter(fontWeight: FontWeight.w400, letterSpacing: 0.2),
      ),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: systemUiStyle,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: onSurface,
        ),
        iconTheme: IconThemeData(color: onSurfaceMid, size: 24),
        actionsIconTheme: IconThemeData(color: onSurfaceMid, size: 24),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFDADCE0),
            width: 1,
          ),
        ),
      ),

      // ── Input ───────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        labelStyle: TextStyle(color: onSurfaceMid),
        hintStyle: TextStyle(color: onSurfaceFaint),
        prefixIconColor: onSurfaceMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFDADCE0),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _seedColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: _onPrimary,
          backgroundColor: _seedColor,
          disabledForegroundColor: onSurfaceFaint,
          disabledBackgroundColor: onSurfaceFaint.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: _onPrimary,
          backgroundColor: _seedColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _seedColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: _seedColor.withValues(alpha: 0.4), width: 1.5),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _seedColor,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── Icon Button ─────────────────────────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurfaceMid,
          highlightColor: _seedColor.withValues(alpha: 0.08),
        ),
      ),

      // ── Segmented Button ────────────────────────────────────────────────────
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: _seedColor.withValues(alpha: isDark ? 0.2 : 0.12),
          selectedForegroundColor: _seedColor,
          foregroundColor: onSurfaceMid,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFDADCE0),
          ),
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _seedColor;
          return isDark ? const Color(0xFF8E918F) : const Color(0xFFB0B3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _seedColor.withValues(alpha: 0.3);
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08);
        }),
      ),

      // ── Slider ──────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: _seedColor,
        thumbColor: _seedColor,
        overlayColor: _seedColor.withValues(alpha: 0.12),
        inactiveTrackColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // ── Bottom Navigation ───────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: _seedColor.withValues(alpha: isDark ? 0.18 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _seedColor : onSurfaceMid,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? _seedColor : onSurfaceMid,
          );
        }),
        elevation: 0,
        height: 64,
      ),

      // ── Chip ────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? _darkSurfaceVariant : _lightSurfaceVariant,
        selectedColor: _seedColor.withValues(alpha: isDark ? 0.2 : 0.12),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurfaceMid,
        ),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFDADCE0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Snack Bar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF313133) : const Color(0xFF1F1F1F),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        actionTextColor: const Color(0xFFA8C7FA),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // ── Dialog ──────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkSurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: onSurfaceMid,
          height: 1.5,
        ),
      ),

      // ── List Tile ───────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: onSurface,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 12,
          color: onSurfaceMid,
        ),
        iconColor: onSurfaceMid,
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFDADCE0),
        thickness: 1,
        space: 1,
      ),

      // ── Progress Indicator ──────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _seedColor,
        linearTrackColor: Color(0xFFD3E3FD),
      ),
    );
  }
}
