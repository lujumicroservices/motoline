import '../analytics/lean_neutral.dart';
import '../models/track_point.dart';

/// Peak lean inside a corner window, plus the GPS samples that bound it.
class MaxLeanHit {
  const MaxLeanHit({
    required this.peakIndex,
    required this.signedLeanDeg,
    required this.fromIndex,
    required this.toIndex,
    required this.fromPoint,
    required this.toPoint,
  });

  /// Sample with the highest |relative lean|.
  final int peakIndex;

  /// Relative lean at peak (negative = left).
  final double signedLeanDeg;

  /// First / last indices where lean stays near the peak (≥92% of max |lean|).
  final int fromIndex;
  final int toIndex;
  final TrackPoint fromPoint;
  final TrackPoint toPoint;

  double get absLeanDeg => signedLeanDeg.abs();
  String get side => signedLeanDeg < 0 ? 'left' : 'right';
}

/// Find max relative lean in [lo]…[hi] (inclusive), independent of apex/speed.
MaxLeanHit? findMaxLeanInWindow({
  required List<TrackPoint> samples,
  required int lo,
  required int hi,
  required double neutralLeanDegrees,
  double plateauFraction = 0.92,
}) {
  if (samples.isEmpty) return null;
  final a = lo.clamp(0, samples.length - 1);
  final b = hi.clamp(a, samples.length - 1);

  var peakI = a;
  var peakLean = 0.0;
  var found = false;
  for (var i = a; i <= b; i++) {
    final raw = samples[i].leanDegrees;
    if (raw == null) continue;
    final rel = relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralLeanDegrees,
    );
    if (!found || rel.abs() > peakLean.abs()) {
      found = true;
      peakLean = rel;
      peakI = i;
    }
  }
  if (!found) return null;

  final thresh = peakLean.abs() * plateauFraction;
  var from = peakI;
  var to = peakI;
  for (var i = peakI; i >= a; i--) {
    final raw = samples[i].leanDegrees;
    if (raw == null) break;
    final rel = relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralLeanDegrees,
    );
    // Same side and near peak.
    if (rel.sign != peakLean.sign && rel.abs() > 1) break;
    if (rel.abs() < thresh) break;
    from = i;
  }
  for (var i = peakI; i <= b; i++) {
    final raw = samples[i].leanDegrees;
    if (raw == null) break;
    final rel = relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralLeanDegrees,
    );
    if (rel.sign != peakLean.sign && rel.abs() > 1) break;
    if (rel.abs() < thresh) break;
    to = i;
  }
  // Ensure two distinct GPS points when possible.
  if (from == to) {
    if (to < b) {
      to = to + 1;
    } else if (from > a) {
      from = from - 1;
    }
  }

  return MaxLeanHit(
    peakIndex: peakI,
    signedLeanDeg: peakLean,
    fromIndex: from,
    toIndex: to,
    fromPoint: samples[from],
    toPoint: samples[to],
  );
}
