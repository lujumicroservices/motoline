import '../analytics/lean_neutral.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';

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

/// Map focus that always keeps track line on both sides of [centerIndex].
///
/// Starts from optional [seedLo]…[seedHi] (e.g. corner analysis window), then
/// walks along the GPS path until each side has at least [minSideMeters]
/// (and [minSideSamples] points when the path allows).
({int lo, int hi}) padTrackAroundIndex({
  required List<TrackPoint> samples,
  required int centerIndex,
  int? seedLo,
  int? seedHi,
  double minSideMeters = 55,
  int minSideSamples = 8,
}) {
  if (samples.isEmpty) return (lo: 0, hi: 0);
  final last = samples.length - 1;
  final center = centerIndex.clamp(0, last);

  var lo = (seedLo ?? center).clamp(0, last);
  var hi = (seedHi ?? center).clamp(lo, last);
  if (center < lo) lo = center;
  if (center > hi) hi = center;

  var leftDist = 0.0;
  var leftCount = center - lo;
  var i = lo;
  while (i > 0 &&
      (leftDist < minSideMeters || leftCount < minSideSamples)) {
    leftDist += haversineMeters(
      samples[i].latitude,
      samples[i].longitude,
      samples[i - 1].latitude,
      samples[i - 1].longitude,
    );
    i -= 1;
    leftCount += 1;
  }
  lo = i;

  var rightDist = 0.0;
  var rightCount = hi - center;
  var j = hi;
  while (j < last &&
      (rightDist < minSideMeters || rightCount < minSideSamples)) {
    rightDist += haversineMeters(
      samples[j].latitude,
      samples[j].longitude,
      samples[j + 1].latitude,
      samples[j + 1].longitude,
    );
    j += 1;
    rightCount += 1;
  }
  hi = j;

  return (lo: lo, hi: hi);
}

/// Top relative-lean peaks across a ride (fallback when road-stretch curves miss).
List<MaxLeanHit> findTopLeanPeaks({
  required List<TrackPoint> samples,
  required double neutralLeanDegrees,
  int maxPeaks = 5,
  double minAbsLeanDeg = 12,
  int minSeparationSamples = 8,
}) {
  if (samples.length < 4) return const [];

  final scored = <({int i, double lean})>[];
  for (var i = 1; i < samples.length - 1; i++) {
    final raw = samples[i].leanDegrees;
    if (raw == null) continue;
    final lean = relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralLeanDegrees,
    );
    if (lean.abs() < minAbsLeanDeg) continue;
    final prevRaw = samples[i - 1].leanDegrees;
    final nextRaw = samples[i + 1].leanDegrees;
    if (prevRaw == null || nextRaw == null) continue;
    final prev = relativeLeanDegrees(
      rawLeanDegrees: prevRaw,
      neutralDegrees: neutralLeanDegrees,
    ).abs();
    final next = relativeLeanDegrees(
      rawLeanDegrees: nextRaw,
      neutralDegrees: neutralLeanDegrees,
    ).abs();
    if (lean.abs() >= prev && lean.abs() >= next) {
      scored.add((i: i, lean: lean));
    }
  }
  scored.sort((a, b) => b.lean.abs().compareTo(a.lean.abs()));

  final picked = <MaxLeanHit>[];
  for (final s in scored) {
    if (picked.any((p) => (p.peakIndex - s.i).abs() < minSeparationSamples)) {
      continue;
    }
    final lo = (s.i - 6).clamp(0, samples.length - 1);
    final hi = (s.i + 6).clamp(lo, samples.length - 1);
    final hit = findMaxLeanInWindow(
      samples: samples,
      lo: lo,
      hi: hi,
      neutralLeanDegrees: neutralLeanDegrees,
    );
    if (hit == null) continue;
    picked.add(hit);
    if (picked.length >= maxPeaks) break;
  }
  return picked;
}
