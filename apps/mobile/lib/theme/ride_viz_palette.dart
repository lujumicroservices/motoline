import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared colors for speed and lean visualizations (REQ-SPEED-COLOR, REQ-LEAN-COLOR).
class RideVizPalette {
  RideVizPalette._();

  /// Top of the speed color ramp (km/h).
  static const speedCapKmh = 250.0;

  /// Street-biased stops: warm hues arrive early so normal riders feel quick.
  /// High-contrast hues (not one red family). Cap still covers track speeds.
  static const speedStops = <(double kmh, Color color)>[
    (0, Color(0xFF1B4DFF)), // electric blue — crawl / stopped
    (25, Color(0xFF00E5A8)), // mint — neighborhood
    (45, Color(0xFFC6FF00)), // lime — city cruise
    (65, Color(0xFFFFD600)), // yellow — brisk street (feels quick)
    (90, Color(0xFFFF6D00)), // orange — highway / spirited
    (130, Color(0xFFFF1744)), // hot red — properly fast
    (250, Color(0xFFD500F9)), // magenta — top end
  ];

  static const speedMid = Color(0xFFFFD600);

  /// Brake hardness accents (distinct from lean cyan/amber).
  static const brakeLight = Color(0xFFFFF59D);
  static const brakeMedium = Color(0xFFFFAB40);
  static const brakeHard = Color(0xFFFF1744);

  /// Left bank — cyan (not green; not the speed ramp).
  static const leanLeft = Color(0xFF4CC9F0);

  /// Right bank — amber.
  static const leanRight = Color(0xFFF4A261);

  /// Road-kind map contrast: muted straight vs hot turn.
  static const roadRecta = Color(0xFF7A8799);
  static const roadCurva = Color(0xFFFF2D95);
  static const roadCurvaLeft = leanLeft;
  static const roadCurvaRight = leanRight;

  /// High-contrast multi-hue speed color (easy to see slow vs fast).
  static Color speedColor(double speedKmh) {
    final v = speedKmh.clamp(0.0, speedCapKmh);
    final stops = speedStops;
    if (v <= stops.first.$1) return stops.first.$2;
    if (v >= stops.last.$1) return stops.last.$2;
    for (var i = 1; i < stops.length; i++) {
      final (k0, c0) = stops[i - 1];
      final (k1, c1) = stops[i];
      if (v <= k1) {
        final t = ((v - k0) / (k1 - k0)).clamp(0.0, 1.0);
        return Color.lerp(c0, c1, t)!;
      }
    }
    return stops.last.$2;
  }

  static Color brakeColor(BrakeHardness hardness) {
    return switch (hardness) {
      BrakeHardness.light => brakeLight,
      BrakeHardness.medium => brakeMedium,
      BrakeHardness.hard => brakeHard,
    };
  }

  /// Lean degrees: negative = left, positive = right.
  static Color leanColor(double leanDegrees) {
    if (leanDegrees < -1) return leanLeft;
    if (leanDegrees > 1) return leanRight;
    return AppTheme.mist;
  }
}

enum BrakeHardness { light, medium, hard }
