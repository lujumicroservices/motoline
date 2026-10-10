import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OFF mode chrome, taken from the Métrica M5 firmware (0.6.2-circuit.4):
/// dark field, bright orange track fill, sector colours S1 red / S2 cyan /
/// S3 green / S4 magenta, dark outlines on sector lines and gates.
class OffroadTheme {
  static const field = Color(0xFF050505);
  static const panel = Color(0xFF141414);
  static const panelBorder = Color(0xFF3A3A3A);
  static const text = Color(0xFFFFFFFF);

  /// Secondary copy that still reads in direct sun.
  static const textMuted = Color(0xFFE6E6E6);
  static const textFaint = Color(0xFFB8B8B8);

  /// Track fill — firmware 0xFC60 (RGB 255,140,0).
  static const track = Color(0xFFFF8C00);
  static const outline = Color(0xFF000000);

  static const sectorColors = [
    Color(0xFFFF3B30),
    Color(0xFF00E5FF),
    Color(0xFF39FF14),
    Color(0xFFFF2BD6),
  ];

  static Color sector(int index) => sectorColors[index % sectorColors.length];

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;

  static TextStyle hud(double size, {Color color = text}) => GoogleFonts.rajdhani(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static TextStyle label({Color color = textMuted}) => GoogleFonts.exo2(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: 0.6,
  );

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        surface: field,
        primary: track,
        secondary: track,
        onSurface: text,
        onPrimary: outline,
        error: Color(0xFFFF3B30),
      ),
      scaffoldBackgroundColor: field,
    );
    return base.copyWith(
      textTheme: GoogleFonts.exo2TextTheme(
        base.textTheme,
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: field,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.exo2(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: panelBorder),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: track,
        unselectedLabelColor: textFaint,
        indicatorColor: track,
        labelStyle: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.exo2(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        dividerColor: panelBorder,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: track,
          foregroundColor: outline,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? outline : textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? track : panelBorder,
        ),
      ),
    );
  }
}
