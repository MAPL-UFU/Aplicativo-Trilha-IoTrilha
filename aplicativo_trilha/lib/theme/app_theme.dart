// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Cores "Trilha & Aventura"
  static const Color primary = Color(0xFF2E7D32);      // Verde Floresta
  static const Color primaryDark = Color(0xFF1B5E20);  // Verde Escuro
  static const Color accent = Color(0xFFFF6D00);       // Laranja Pôr do Sol (para ações)
  static const Color background = Color(0xFFF5F5F5);   // Off-white
  static const Color surface = Colors.white;
  static const Color textDark = Color(0xFF263238);     // Cinza quase preto

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      
      // Definição de Cores Principal
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        surface: surface,
      ),

      // Tipografia Moderna
      textTheme: GoogleFonts.latoTextTheme().copyWith(
        headlineSmall: GoogleFonts.montserrat(
          fontWeight: FontWeight.bold, 
          color: textDark
        ),
        titleLarge: GoogleFonts.montserrat(
          fontWeight: FontWeight.bold,
          color: textDark
        ),
      ),

      // Estilo dos Inputs (Login/Forms)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Botões Elevados (Arredondados e Grandes)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      
      // Floating Action Buttons
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}