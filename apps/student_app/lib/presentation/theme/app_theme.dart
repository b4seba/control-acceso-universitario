import 'package:flutter/material.dart';

class AppTheme {
  // Paleta Institucional Universidad
  static const Color navyDark = Color(0xFF0A192F);       // Fondo principal profundo
  static const Color navySurface = Color(0xFF112240);    // Tarjetas y superficies elevadas
  static const Color navyBorder = Color(0xFF233554);     // Bordes sutiles
  
  static const Color primaryBlue = Color(0xFF0077B6);    // Azul institucional principal
  static const Color autonomousBlue = primaryBlue;       // Compatibilidad hacia atrás
  static const Color cobaltAccent = Color(0xFF00B4D8);   // Acento de alta visibilidad
  static const Color cyanNfc = Color(0xFF48CAE4);        // Indicador ondas de radiofrecuencia
  
  static const Color emeraldSuccess = Color(0xFF10B981); // Matrícula vigente / Acceso OK
  static const Color amberWarning = Color(0xFFF59E0B);   // Advertencia / NFC Read
  static const Color crimsonDenied = Color(0xFFEF4444);  // Suspendido / Acceso Denegado
  
  static const Color textPrimary = Color(0xFFF8FAFC);    // Blanco tiza de alto contraste
  static const Color textSecondary = Color(0xFF94A3B8);  // Gris neutro legible
  static const Color textMuted = Color(0xFF64748B);      // Texto auxiliar

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navyDark,
      colorScheme: const ColorScheme.dark(
        primary: autonomousBlue,
        secondary: cobaltAccent,
        surface: navySurface,
        error: crimsonDenied,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: navySurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: navyBorder, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: autonomousBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF162A45),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: cobaltAccent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cobaltAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: crimsonDenied, width: 1.5),
        ),
      ),
    );
  }
}
