import 'package:flutter/material.dart';

class KioskTheme {
  // Matte anti-glare industrial palette for 7" & desktop edge turnstile terminals
  static const Color industrialBlack = Color(0xFF0F1115);
  static const Color industrialSurface = Color(0xFF171A21);
  static const Color industrialCard = Color(0xFF1E222B);
  static const Color industrialBorder = Color(0xFF262B36);
  static const Color industrialBorderStrong = Color(0xFF343B4A);

  // Institutional accent & restrained hardware state signals (WCAG AA verified)
  static const Color brandCrimson = Color(0xFF9E1B32);
  static const Color crimsonText = Color(0xFFF07185);

  static const Color signalIdle = Color(0xFF3B82F6);
  static const Color signalScanning = Color(0xFF38BDF8);
  static const Color signalAmber = Color(0xFFFBBF24);
  static const Color signalAmberBg = Color(0xFF261E0D);

  static const Color signalGranted = Color(0xFF22C55E);
  static const Color signalGrantedText = Color(0xFF4ADE80);
  static const Color signalGrantedBg = Color(0xFF0E2219);

  static const Color signalDenied = Color(0xFFF87171);
  static const Color signalDeniedBg = Color(0xFF231215);

  static const Color textWhite = Color(0xFFF4F4F5);
  static const Color textGrey = Color(0xFFA1A1AA);
  static const Color textMuted = Color(0xFF8E95A2);

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
      brightness: Brightness.dark,
      scaffoldBackgroundColor: industrialBlack,
      colorScheme: const ColorScheme.dark(
        primary: brandCrimson,
        secondary: signalScanning,
        surface: industrialSurface,
        error: signalDenied,
        onPrimary: Colors.white,
        onSurface: textWhite,
      ),
      fontFamilyFallback: sansFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: industrialSurface,
        foregroundColor: textWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: industrialSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: industrialBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandCrimson,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            fontFamilyFallback: sansFallback,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textWhite,
          minimumSize: const Size(40, 40),
          side: const BorderSide(color: industrialBorderStrong, width: 1),
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
        fillColor: industrialCard,
        labelStyle: const TextStyle(color: textGrey, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIconColor: textGrey,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: industrialBorderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: industrialBorderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: signalScanning, width: 1.5),
        ),
      ),
    );
  }
}
