import 'dart:math' as math;

import '../models/track_point.dart';
import '../utils/geo_utils.dart';

/// One contiguous shared corridor between tracks A and B.
class TrackOverlapRun {
  const TrackOverlapRun({
    required this.aStartOrig,
    required this.aEndOrig,
    required this.bStartOrig,
    required this.bEndOrig,
    required this.lengthMeters,
  });

  /// Inclusive indices into the **original** A samples.
  final int aStartOrig;
  final int aEndOrig;

  /// Inclusive indices into the **original** B samples.
  final int bStartOrig;
  final int bEndOrig;

  final double lengthMeters;
}

/// Spatial corridor overlap between two GPS tracks (same place + direction).
class TrackOverlapResult {
  const TrackOverlapResult({
    required this.pathMetersA,
    required this.pathMetersB,
    required this.sharedMeters,
    required this.matchPctA,
    required this.matchPctB,
    required this.runs,
  });

  static const empty = TrackOverlapResult(
    pathMetersA: 0,
    pathMetersB: 0,
    sharedMeters: 0,
    matchPctA: 0,
    matchPctB: 0,
    runs: [],
  );

  final double pathMetersA;
  final double pathMetersB;

  /// Sum of contiguous shared corridor lengths (meters).
  final double sharedMeters;

  /// [sharedMeters] / [pathMetersA] (0–1).
  final double matchPctA;

  /// [sharedMeters] / [pathMetersB] (0–1).
  final double matchPctB;

  final List<TrackOverlapRun> runs;

  TrackOverlapRun? get longestRun {
    if (runs.isEmpty) return null;
    return runs.reduce((a, b) => a.lengthMeters >= b.lengthMeters ? a : b);
  }

  bool meetsMinMatch({
    double minPct = 0.15,
    double minSharedMeters = 200,
  }) {
    return sharedMeters >= minSharedMeters || matchPctA >= minPct;
  }
}

/// Match tracks that follow the same road corridor in the same direction.
class TrackOverlapMatcher {
  const TrackOverlapMatcher({
    this.corridorRadiusM = 40,
    this.resampleStepM = 10,
    this.minRunMeters = 80,
  });

  final double corridorRadiusM;
  final double resampleStepM;
  final double minRunMeters;

  TrackOverlapResult compute(List<TrackPoint> a, List<TrackPoint> b) {
    final pathA = pathDistanceMeters(a);
    final pathB = pathDistanceMeters(b);
    if (a.length < 2 || b.length < 2 || pathA < minRunMeters) {
      return TrackOverlapResult(
        pathMetersA: pathA,
        pathMetersB: pathB,
        sharedMeters: 0,
        matchPctA: 0,
        matchPctB: 0,
        runs: const [],
      );
    }

    final ra = _resample(a, resampleStepM);
    final rb = _resample(b, resampleStepM);
    if (ra.points.length < 2 || rb.points.length < 2) {
      return TrackOverlapResult(
        pathMetersA: pathA,
        pathMetersB: pathB,
        sharedMeters: 0,
        matchPctA: 0,
        matchPctB: 0,
        runs: const [],
      );
    }

    final match = List<bool>.filled(ra.points.length, false);
    final nearestB = List<int>.filled(ra.points.length, -1);

    for (var i = 0; i < ra.points.length; i++) {
      final p = ra.points[i];
      final j = _nearestIndex(rb.points, p.latitude, p.longitude);
      if (j < 0) continue;
      final d = haversineMeters(
        p.latitude,
        p.longitude,
        rb.points[j].latitude,
        rb.points[j].longitude,
      );
      if (d > corridorRadiusM) continue;
      if (!_sameDirection(ra.points, i, rb.points, j)) continue;
      match[i] = true;
      nearestB[i] = j;
    }

    final runs = <TrackOverlapRun>[];
    var i = 0;
    while (i < match.length) {
      if (!match[i]) {
        i++;
        continue;
      }
      final start = i;
      var end = i;
      while (end + 1 < match.length && match[end + 1]) {
        end++;
      }
      final len = _pathLen(ra.points, start, end);
      if (len >= minRunMeters) {
        var bLo = nearestB[start];
        var bHi = nearestB[start];
        for (var k = start; k <= end; k++) {
          final bj = nearestB[k];
          if (bj < 0) continue;
          if (bj < bLo) bLo = bj;
          if (bj > bHi) bHi = bj;
        }
        if (bLo >= 0 && bHi >= bLo) {
          runs.add(
            TrackOverlapRun(
              aStartOrig: ra.originalIndex[start],
              aEndOrig: ra.originalIndex[end],
              bStartOrig: rb.originalIndex[bLo],
              bEndOrig: rb.originalIndex[bHi],
              lengthMeters: len,
            ),
          );
        }
      }
      i = end + 1;
    }

    final shared = runs.fold<double>(0, (s, r) => s + r.lengthMeters);
    return TrackOverlapResult(
      pathMetersA: pathA,
      pathMetersB: pathB,
      sharedMeters: shared,
      matchPctA: pathA <= 0 ? 0 : (shared / pathA).clamp(0.0, 1.0),
      matchPctB: pathB <= 0 ? 0 : (shared / pathB).clamp(0.0, 1.0),
      runs: runs,
    );
  }

  /// Points from [samples] that fall inside any overlap run on side A or B.
  static List<TrackPoint> pointsInRunsA(
    List<TrackPoint> samples,
    TrackOverlapResult overlap,
  ) {
    return _pointsInRuns(samples, overlap.runs, aSide: true);
  }

  static List<TrackPoint> pointsInRunsB(
    List<TrackPoint> samples,
    TrackOverlapResult overlap,
  ) {
    return _pointsInRuns(samples, overlap.runs, aSide: false);
  }

  static List<TrackPoint> _pointsInRuns(
    List<TrackPoint> samples,
    List<TrackOverlapRun> runs, {
    required bool aSide,
  }) {
    if (samples.isEmpty || runs.isEmpty) return const [];
    final keep = List<bool>.filled(samples.length, false);
    for (final r in runs) {
      final lo = aSide ? r.aStartOrig : r.bStartOrig;
      final hi = aSide ? r.aEndOrig : r.bEndOrig;
      final a = lo.clamp(0, samples.length - 1);
      final b = hi.clamp(a, samples.length - 1);
      for (var i = a; i <= b; i++) {
        keep[i] = true;
      }
    }
    return [
      for (var i = 0; i < samples.length; i++)
        if (keep[i]) samples[i],
    ];
  }
}

class _Resampled {
  const _Resampled({required this.points, required this.originalIndex});
  final List<TrackPoint> points;
  final List<int> originalIndex;
}

_Resampled _resample(List<TrackPoint> samples, double stepMeters) {
  if (samples.isEmpty) {
    return const _Resampled(points: [], originalIndex: []);
  }
  final out = <TrackPoint>[samples.first];
  final idx = <int>[0];
  var acc = 0.0;
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1];
    final b = samples[i];
    acc += haversineMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (acc >= stepMeters) {
      out.add(b);
      idx.add(i);
      acc = 0;
    }
  }
  if (idx.last != samples.length - 1) {
    out.add(samples.last);
    idx.add(samples.length - 1);
  }
  return _Resampled(points: out, originalIndex: idx);
}

int _nearestIndex(List<TrackPoint> points, double lat, double lng) {
  if (points.isEmpty) return -1;
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = haversineMeters(
      lat,
      lng,
      points[i].latitude,
      points[i].longitude,
    );
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

double _pathLen(List<TrackPoint> points, int start, int end) {
  if (end <= start) return 0;
  var total = 0.0;
  for (var i = start + 1; i <= end; i++) {
    total += haversineMeters(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return total;
}

bool _sameDirection(
  List<TrackPoint> a,
  int ai,
  List<TrackPoint> b,
  int bi,
) {
  final ba = _bearingAt(a, ai);
  final bb = _bearingAt(b, bi);
  if (ba == null || bb == null) return true;
  final d = _toRad(ba - bb);
  return math.cos(d) > 0;
}

double? _bearingAt(List<TrackPoint> points, int i) {
  if (points.length < 2) return null;
  if (i > 0) {
    return _bearingDeg(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return _bearingDeg(
    points[i].latitude,
    points[i].longitude,
    points[i + 1].latitude,
    points[i + 1].longitude,
  );
}

double _bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _toRad(lat1);
  final phi2 = _toRad(lat2);
  final dLon = _toRad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _toRad(double deg) => deg * math.pi / 180;
