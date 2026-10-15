import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'session_model.dart';

/// What the pass line is coloured by on the map, the 3D view and the charts.
enum TraceChannel { speed, longG, lean, latG, elevation, offLine }

/// Speed ramp shared with the logger HTML maps (cold → hot).
const _heat = [
  Color(0xFF4CC9F0),
  Color(0xFF7CFC9A),
  Color(0xFFF4D35E),
  Color(0xFFFF8C00),
  Color(0xFFFF3B30),
];
const _terrain = [
  Color(0xFF1B7F3B),
  Color(0xFF8DBF3F),
  Color(0xFFE0C35A),
  Color(0xFFB0703A),
  Color(0xFFF2F2F2),
];
const _brakeRed = Color(0xFFFF3B30);
const _throttleGreen = Color(0xFF39FF14);
const _neutral = Color(0xFFE6E6E6);

Color _ramp(List<Color> stops, double t) {
  final x = t.clamp(0.0, 1.0) * (stops.length - 1);
  final i = x.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], x - i)!;
}

extension TraceChannelX on TraceChannel {
  String label(AppLocalizations l10n) => switch (this) {
    TraceChannel.speed => l10n.channelSpeed,
    TraceChannel.longG => l10n.channelLongG,
    TraceChannel.lean => l10n.channelLean,
    TraceChannel.latG => l10n.channelLatG,
    TraceChannel.elevation => l10n.channelElevation,
    TraceChannel.offLine => l10n.channelOffLine,
  };

  IconData get icon => switch (this) {
    TraceChannel.speed => Icons.speed_rounded,
    TraceChannel.longG => Icons.compare_arrows_rounded,
    TraceChannel.lean => Icons.rotate_90_degrees_ccw_rounded,
    TraceChannel.latG => Icons.u_turn_left_rounded,
    TraceChannel.elevation => Icons.terrain_rounded,
    TraceChannel.offLine => Icons.highlight_off_rounded,
  };

  String get unit => switch (this) {
    TraceChannel.speed => 'km/h',
    TraceChannel.longG || TraceChannel.latG => 'g',
    TraceChannel.lean => '°',
    TraceChannel.elevation || TraceChannel.offLine => 'm',
  };

  /// Lean and lateral g come from GNSS (speed × yaw rate).
  bool get estimated => this == TraceChannel.lean || this == TraceChannel.latG;

  /// Braking / throttle is the only signed scale: red below 0, green above.
  bool get diverging => this == TraceChannel.longG;

  double value(PassTrace t, int i) => switch (this) {
    TraceChannel.speed => t.kmh[i],
    TraceChannel.longG => t.longG[i],
    TraceChannel.lean => t.lean[i].abs(),
    TraceChannel.latG => t.latG[i].abs(),
    TraceChannel.elevation => t.alt[i],
    TraceChannel.offLine => t.outsideM[i],
  };

  /// Colour-scale bounds. Signed scales are symmetric around 0.
  (double, double) range(PassTrace t) {
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < t.length; i++) {
      final v = value(t, i);
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    return switch (this) {
      TraceChannel.longG => () {
        final m = math.max(0.15, math.max(lo.abs(), hi.abs()));
        return (-m, m);
      }(),
      TraceChannel.elevation => (lo, math.max(hi, lo + 1)),
      // Under 0.5 m off the corridor reads as GNSS noise, not a wide line.
      TraceChannel.offLine => (0.0, math.max(hi, 0.5)),
      _ => (0.0, math.max(hi, 1e-3)),
    };
  }

  Color color(double v, (double, double) r) {
    final (lo, hi) = r;
    if (diverging) {
      if (v < 0) return Color.lerp(_neutral, _brakeRed, (v / lo).clamp(0, 1))!;
      return Color.lerp(_neutral, _throttleGreen, (v / hi).clamp(0, 1))!;
    }
    final t = (v - lo) / (hi - lo);
    return switch (this) {
      TraceChannel.elevation => _ramp(_terrain, t),
      TraceChannel.offLine =>
        v <= 0 ? const Color(0xFF39FF14) : _ramp(_heat.sublist(2), t),
      _ => _ramp(_heat, t),
    };
  }

  /// Stops for a legend bar, low → high.
  List<Color> legend() => switch (this) {
    TraceChannel.longG => const [_brakeRed, _neutral, _throttleGreen],
    TraceChannel.elevation => _terrain,
    TraceChannel.offLine => [const Color(0xFF39FF14), ..._heat.sublist(2)],
    _ => _heat,
  };

  String format(double v) => switch (this) {
    TraceChannel.speed || TraceChannel.lean => v.toStringAsFixed(0),
    TraceChannel.longG => '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}',
    TraceChannel.latG => v.toStringAsFixed(2),
    TraceChannel.elevation => v.toStringAsFixed(0),
    TraceChannel.offLine => v.toStringAsFixed(1),
  };
}

/// Contiguous braking rows `(first, last)` of a trace.
List<(int, int)> brakeRuns(PassTrace t) {
  final out = <(int, int)>[];
  int? start;
  for (var i = 0; i < t.length; i++) {
    if (t.braking[i] == 1) {
      start ??= i;
    } else if (start != null) {
      out.add((start, i - 1));
      start = null;
    }
  }
  if (start != null) out.add((start, t.length - 1));
  return out;
}

/// Zones from the asset when it carries row ranges, else from the braking flag.
List<(int, int)> passBrakeRanges(TrainingPass p) {
  final t = p.trace;
  if (t == null) return const [];
  if (p.brakes.isNotEmpty && p.brakes.every((b) => b.i0 != null)) {
    return [
      for (final b in p.brakes)
        (b.i0!.clamp(0, t.length - 1), b.i1!.clamp(0, t.length - 1)),
    ];
  }
  return brakeRuns(t);
}
