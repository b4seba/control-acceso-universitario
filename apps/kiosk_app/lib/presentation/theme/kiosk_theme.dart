import 'package:flutter/material.dart';

class KioskTheme {
  // Colores Industriales de Alto Contraste para Terminales Táctiles de 7"
  static const Color industrialBlack = Color(0xFF070B19);
  static const Color industrialSurface = Color(0xFF0F172A);
  static const Color industrialCard = Color(0xFF1E293B);
  static const Color industrialBorder = Color(0xFF334155);

  // Halos Cromáticos Semánticos de la FSM
  static const Color haloIdle = Color(0xFF0077B6);         // Azul Neón Cobalto
  static const Color haloNfcReading = Color(0xFFF59E0B);    // Ámbar / Naranja Industrial
  static const Color haloFaceScanning = Color(0xFF06B6D4);  // Cian Retícula Biométrica
  static const Color haloGranted = Color(0xFF10B981);       // Verde Esmeralda Pulsante
  static const Color haloDenied = Color(0xFFEF4444);        // Rojo Carmesí Alerta

  static const Color textWhite = Color(0xFFF8FAFC);
  static const Color textGrey = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static ThemeData get industrialTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: industrialBlack,
      colorScheme: const ColorScheme.dark(
        primary: haloIdle,
        secondary: haloFaceScanning,
        surface: industrialSurface,
        error: haloDenied,
        onSurface: textWhite,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: industrialSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: industrialBorder, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: haloIdle,
          foregroundColor: Colors.white,
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: industrialCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: industrialBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: industrialBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: haloFaceScanning, width: 2),
        ),
      ),
    );
  }
}
