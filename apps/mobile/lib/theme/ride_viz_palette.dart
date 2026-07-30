import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Shared colors for speed and lean visualizations (REQ-SPEED-COLOR, REQ-LEAN-COLOR).
class RideVizPalette {
  RideVizPalette._();

  /// Top of the speed intensity ramp (km/h) → darkest red.
  static const speedCapKmh = 300.0;

  /// Slow — pale / clear red (easy to read as “not fast”).
  static const speedClear = Color(0xFFFFD6CE);

  /// Mid red for legends / brand-adjacent accents.
  static const speedMid = Color(0xFFE85A4F);

  /// Fast — deep dark red.
  static const speedDark = Color(0xFF5C0008);

  /// Left bank — cyan (not green; not the speed reds).
  static const leanLeft = Color(0xFF4CC9F0);

  /// Right bank — amber (not green; not the speed reds).
  static const leanRight = Color(0xFFF4A261);

  /// One red intensity ramp: clear/pale at 0 → dark red at [speedCapKmh]+.
  static Color speedColor(double speedKmh) {
    final t = (speedKmh / speedCapKmh).clamp(0.0, 1.0);
    // Ease so mid speeds still feel “warmer” than crawl.
    final eased = Curves.easeIn.transform(t);
    if (eased <= 0.55) {
      return Color.lerp(speedClear, speedMid, eased / 0.55)!;
    }
    return Color.lerp(speedMid, speedDark, (eased - 0.55) / 0.45)!;
  }

  /// Lean degrees: negative = left, positive = right.
  static Color leanColor(double leanDegrees) {
    if (leanDegrees < -1) return leanLeft;
    if (leanDegrees > 1) return leanRight;
    return AppTheme.mist;
  }
}
