import 'package:flutter/material.dart';

/// Shared corner radii. Buttons use [button] so tall CTAs read as rounded,
/// not slabs.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;

  /// Cards, toasts, list surfaces.
  static const double card = 20;

  /// Text fields.
  static const double field = 16;

  /// Filled, outlined, elevated, and text buttons.
  static const double button = 28;

  /// Dialogs and bottom sheets.
  static const double sheet = 28;
}

/// Shared spacing scale for new chrome. Existing screens keep their padding.
abstract final class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Bundled faces. UI is Plus Jakarta Sans (offline asset). The wordmark stays
/// Barlow Condensed so the lockup shape does not change.
abstract final class AppFonts {
  static const String uiFamily = 'PlusJakartaSans';
  static const String brandFamily = 'BarlowCondensed';

  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle display({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => _ui(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  static TextStyle body({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => _ui(
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontStyle: fontStyle,
    shadows: shadows,
  );

  /// Condensed race lockup used by the header wordmark.
  static TextStyle brand({
    double fontSize = 34,
    FontWeight fontWeight = FontWeight.w800,
    double letterSpacing = 0.8,
    double height = 1.0,
    Color? color,
  }) => TextStyle(
    fontFamily: brandFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
  );

  /// Large ride numerals: tabular, tight, glanceable.
  static TextStyle metric({
    double fontSize = 34,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double height = 1,
    Color? color,
  }) => TextStyle(
    fontFamily: uiFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing ?? -0.6,
    height: height,
    color: color,
    fontFeatures: tabularFigures,
  );

  static TextTheme textTheme() {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? tracking,
      bool tabular = false,
    }) => TextStyle(
      fontFamily: uiFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: tracking,
      fontFeatures: tabular ? tabularFigures : null,
    );

    return TextTheme(
      displayLarge: s(
        48,
        FontWeight.w700,
        height: 1,
        tracking: -1.2,
        tabular: true,
      ),
      displayMedium: s(
        40,
        FontWeight.w700,
        height: 1,
        tracking: -0.8,
        tabular: true,
      ),
      displaySmall: s(
        32,
        FontWeight.w700,
        height: 1.05,
        tracking: -0.6,
        tabular: true,
      ),
      headlineLarge: s(28, FontWeight.w700, height: 1.15, tracking: -0.4),
      headlineMedium: s(24, FontWeight.w700, height: 1.2, tracking: -0.2),
      headlineSmall: s(20, FontWeight.w600, height: 1.25),
      titleLarge: s(18, FontWeight.w600, height: 1.3, tracking: -0.1),
      titleMedium: s(16, FontWeight.w600, height: 1.3),
      titleSmall: s(14, FontWeight.w600, height: 1.3, tracking: 0.1),
      bodyLarge: s(16, FontWeight.w500, height: 1.45),
      bodyMedium: s(14, FontWeight.w500, height: 1.45),
      bodySmall: s(12, FontWeight.w500, height: 1.4),
      labelLarge: s(15, FontWeight.w700, height: 1.2, tracking: 0.1),
      labelMedium: s(12, FontWeight.w600, height: 1.2, tracking: 0.2),
      labelSmall: s(11, FontWeight.w600, height: 1.2, tracking: 0.4),
    );
  }

  static TextStyle _ui({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    Color? color,
    FontStyle? fontStyle,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: uiFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
    color: color,
    fontStyle: fontStyle,
    shadows: shadows,
  );
}
