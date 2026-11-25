import 'package:flutter/material.dart';

class AppTheme {
  // Light-first architectural palette inspired by Universidad Autónoma identity
  static const Color canvas = Color(0xFFF5F5F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFEAEAE6);
  static const Color border = Color(0xFFE4E4E0);
  static const Color borderStrong = Color(0xFFD0CFC9);

  // Institutional brand crimson & wallet card burgundy
  static const Color institutionalCrimson = Color(0xFF9E1B32);
  static const Color crimsonPressed = Color(0xFF8C152B);
  static const Color cardBurgundy = Color(0xFF7A1426);
  static const Color cardBurgundyDeep = Color(0xFF5B0D1B);
  static const Color cardBorder = Color(0xFF962A3E);
  static const Color cardTextMuted = Color(0xFFE2C6CC);

  // Semantic statuses (WCAG AA verified)
  static const Color statusVigente = Color(0xFF15803D);
  static const Color statusVigenteBg = Color(0xFFDCFCE7);
  static const Color statusWarning = Color(0xFFB45309);
  static const Color statusWarningBg = Color(0xFFFEF3C7);
  static const Color statusDenied = Color(0xFFB91C1C);
  static const Color statusDeniedBg = Color(0xFFFEE2E2);

  // Typographic inks
  static const Color textPrimary = Color(0xFF18181B);
  static const Color textSecondary = Color(0xFF57534E);
  static const Color textMuted = Color(0xFF68635E);

  static const List<String> sansFallback = [
    'IBM Plex Sans',
    'Noto Sans',
    'Adwaita Sans',
    'sans-serif',
  ];

  static const List<String> monoFallback = [
    'IBM Plex Mono',
    'Adwaita Mono',
    'Liberation Mono',
    'monospace',
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: institutionalCrimson,
        secondary: cardBurgundy,
        surface: surface,
        error: statusDenied,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamilyFallback: sansFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: institutionalCrimson,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            fontFamilyFallback: sansFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: borderStrong, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamilyFallback: sansFallback,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: institutionalCrimson, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: statusDenied, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Compatibility alias preserved for main.dart without modifying entrypoints.
  static ThemeData get darkTheme => lightTheme;
}
