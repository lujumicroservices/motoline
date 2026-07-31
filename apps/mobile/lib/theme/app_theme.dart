import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// RiderLab chrome — carbon asphalt + throttle signal + race telemetry.
class AppTheme {
  /// Deep carbon — night track / fairing black.
  static const asphalt = Color(0xFF0E1013);

  /// Raised panel over asphalt.
  static const asphaltElevated = Color(0xFF1A1E24);

  /// Secondary copy / chrome.
  static const steel = Color(0xFF9BA4AE);

  /// Primary text / light fairing.
  static const mist = Color(0xFFF1F5F8);

  /// Throttle / CTA — hot signal orange-red.
  static const signal = Color(0xFFFF3D1F);

  /// Telemetry / live line — electric mint.
  static const line = Color(0xFF00D4AA);

  /// Peak / warning — race amber.
  static const lineHot = Color(0xFFFFC107);

  /// Brand accent on the wordmark (`Lab`) — same family as throttle signal.
  static const brand = Color(0xFFFF5A2A);

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
