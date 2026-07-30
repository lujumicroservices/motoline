import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const asphalt = Color(0xFF1A1C1E);
  static const asphaltElevated = Color(0xFF24272B);
  static const steel = Color(0xFF9AA3AD);
  static const mist = Color(0xFFE8EEF2);
  static const signal = Color(0xFFE4572E);
  static const line = Color(0xFF2EC4B6);
  static const lineHot = Color(0xFFFFB703);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: asphalt,
        primary: line,
        secondary: signal,
        onSurface: mist,
        onPrimary: asphalt,
        error: signal,
      ),
      scaffoldBackgroundColor: asphalt,
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: mist,
        displayColor: mist,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: asphalt,
        foregroundColor: mist,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: mist,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: asphaltElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: signal,
          foregroundColor: mist,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mist,
          side: const BorderSide(color: steel),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
