import 'package:flutter/material.dart';

class KioskTheme {
  // Light architectural transit-gate palette (high daylight contrast, zero dark neon)
  static const Color canvas = Color(0xFFF3F4F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF8FAFC);
  static const Color surfaceMuted = Color(0xFFECEFF4);
  static const Color border = Color(0xFFE2E6EE);
  static const Color borderStrong = Color(0xFFCBD2DF);

  // Institutional & high-contrast semantic colors (WCAG AA/AAA)
  static const Color brandCrimson = Color(0xFF9E1B32);
  static const Color brandCrimsonDark = Color(0xFF7A1426);
  static const Color brandCrimsonSoft = Color(0xFFFDF2F4);

  static const Color signalIdle = Color(0xFF0284C7);
  static const Color signalIdleBg = Color(0xFFE0F2FE);

  static const Color signalScanning = Color(0xFF0284C7);
  static const Color signalScanningDark = Color(0xFF0369A1);
  static const Color signalScanningBg = Color(0xFFE0F2FE);

  static const Color signalAmber = Color(0xFFD97706);
  static const Color signalAmberText = Color(0xFFB45309);
  static const Color signalAmberBg = Color(0xFFFEF3C7);

  static const Color signalGranted = Color(0xFF16A34A);
  static const Color signalGrantedText = Color(0xFF15803D);
  static const Color signalGrantedBg = Color(0xFFDCFCE7);

  static const Color signalDenied = Color(0xFFDC2626);
  static const Color signalDeniedText = Color(0xFFB91C1C);
  static const Color signalDeniedBg = Color(0xFFFEE2E2);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0D0F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

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

  static ThemeData get industrialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: brandCrimson,
        secondary: signalScanning,
        surface: surface,
        error: signalDenied,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamilyFallback: sansFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
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
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandCrimson,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            fontFamilyFallback: sansFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: surface,
          minimumSize: const Size(42, 42),
          side: const BorderSide(color: borderStrong, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamilyFallback: sansFallback,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtle,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: brandCrimson, width: 1.5),
        ),
      ),
    );
  }
}
