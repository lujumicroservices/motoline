import 'dart:math' as math;

import '../models/track_point.dart';
import '../services/location_service.dart';

double resolveNeutralLeanDegrees({
  required List<TrackPoint> samples,
  double? overrideNeutral,
  bool uprightLocked = false,
}) {
  if (uprightLocked) return 0;
  if (overrideNeutral != null) return overrideNeutral;
  return inferNeutralLeanDegrees(samples);
}

/// Infers pocket/mount “upright” lean so 0° means bike upright, not phone absolute.
///
/// Street rides spend most time near upright; phone-in-pocket adds a constant
/// offset. We estimate that offset from slow / early samples, then fall back
/// to the median lean of the whole ride.
///
/// **Do not use** when the ride froze upright gravity (g0) — lean on points is
/// already bike-relative; call [resolveNeutralLeanDegrees] instead.
double inferNeutralLeanDegrees(List<TrackPoint> samples) {
  final leans = samples
      .map((p) => p.leanDegrees)
      .whereType<double>()
      .toList(growable: false);
  if (leans.isEmpty) return 0;

  final slow = <double>[];
  for (final p in samples) {
    final lean = p.leanDegrees;
    if (lean == null) continue;
    final speed = p.speedKmh ?? 0;
    if (speed < 8) slow.add(lean);
  }
  if (slow.length >= 12) return _median(slow);

  final t0 = samples.first.timestamp;
  final early = <double>[];
  for (final p in samples) {
    final lean = p.leanDegrees;
    if (lean == null) continue;
    if (p.timestamp.difference(t0) <= const Duration(seconds: 12)) {
      early.add(lean);
    }
  }
  if (early.length >= 8) return _median(early);

  return _median(leans);
}

double relativeLeanDegrees({
  required double rawLeanDegrees,
  required double neutralDegrees,
}) =>
    clampLeanDegrees(rawLeanDegrees - neutralDegrees);

LeanSideStats leanSideStats({
  required List<TrackPoint> samples,
  required double neutralDegrees,
}) {
  var maxLeft = 0.0;
  var maxRight = 0.0;
  var leftCount = 0;
  var rightCount = 0;
  var sumAbs = 0.0;
  var n = 0;

  for (final p in samples) {
    final raw = p.leanDegrees;
    if (raw == null) continue;
    final rel = relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralDegrees,
    );
    n++;
    sumAbs += rel.abs();
    if (rel < -2) {
      leftCount++;
      maxLeft = math.max(maxLeft, -rel);
    } else if (rel > 2) {
      rightCount++;
      maxRight = math.max(maxRight, rel);
    }
  }

  return LeanSideStats(
    neutralDegrees: neutralDegrees,
    maxLeftDegrees: maxLeft,
    maxRightDegrees: maxRight,
    leftSampleCount: leftCount,
    rightSampleCount: rightCount,
    avgAbsLeanDegrees: n == 0 ? 0 : sumAbs / n,
    sampleCount: n,
  );
}

class LeanSideStats {
  const LeanSideStats({
    required this.neutralDegrees,
    required this.maxLeftDegrees,
    required this.maxRightDegrees,
    required this.leftSampleCount,
    required this.rightSampleCount,
    required this.avgAbsLeanDegrees,
    required this.sampleCount,
  });

  final double neutralDegrees;
  final double maxLeftDegrees;
  final double maxRightDegrees;
  final int leftSampleCount;
  final int rightSampleCount;
  final double avgAbsLeanDegrees;
  final int sampleCount;

  double get peakAbs => math.max(maxLeftDegrees, maxRightDegrees);
}

double _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}
