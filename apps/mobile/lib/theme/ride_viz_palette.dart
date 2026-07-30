import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared colors for speed and lean visualizations (REQ-SPEED-COLOR, REQ-LEAN-COLOR).
class RideVizPalette {
  RideVizPalette._();

  /// Blue ramp ends at this speed (km/h); above → red.
  static const blueCapKmh = 300.0;

  static const speedBlueLow = Color(0xFF0B1D4A);
  static const speedBlueHigh = Color(0xFF5B9DFF);
  static const speedOverRed = Color(0xFFE4572E);
  static const speedOverRedHot = Color(0xFFB00020);

  /// Left bank — cyan (not green / not red).
  static const leanLeft = Color(0xFF4CC9F0);

  /// Right bank — amber (not green / not red).
  static const leanRight = Color(0xFFF4A261);

  /// Continuous blue 0→300 km/h, then red above 300.
  static Color speedColor(double speedKmh) {
    if (speedKmh > blueCapKmh) {
      final t = ((speedKmh - blueCapKmh) / 100).clamp(0.0, 1.0);
      return Color.lerp(speedOverRed, speedOverRedHot, t)!;
    }
    final t = (speedKmh / blueCapKmh).clamp(0.0, 1.0);
    return Color.lerp(speedBlueLow, speedBlueHigh, Curves.easeInOut.transform(t))!;
  }

  /// Lean degrees: negative = left, positive = right.
  static Color leanColor(double leanDegrees) {
    if (leanDegrees < -1) return leanLeft;
    if (leanDegrees > 1) return leanRight;
    return AppTheme.mist;
  }
}
