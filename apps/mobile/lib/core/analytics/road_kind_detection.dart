import 'dart:math' as math;

import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'lean_neutral.dart';

enum RoadKind {
  /// Straight — recta.
  recta,

  /// Turn — curva.
  curva,
}

enum TurnSide {
  none,
  izquierda,
  derecha,
}

/// Contiguous stretch classified as recta or curva.
class RoadStretch {
  const RoadStretch({
    required this.startIndex,
    required this.endIndex,
    required this.kind,
    required this.side,
    required this.distanceMeters,
    required this.duration,
    required this.headingChangeDeg,
    required this.avgAbsLeanDeg,
    this.peakAbsLeanDeg = 0,
    this.fingerprint,
  });

  final int startIndex;
  final int endIndex;
  final RoadKind kind;
  final TurnSide side;
  final double distanceMeters;
  final Duration duration;
  final double headingChangeDeg;
  final double avgAbsLeanDeg;
  final double peakAbsLeanDeg;

  /// Stable ~25 m grid id of the stretch mid-point (for cross-rider match).
  final String? fingerprint;

  String get labelEs => switch (kind) {
        RoadKind.recta => 'Recta',
        RoadKind.curva => side == TurnSide.izquierda
            ? 'Curva izquierda'
            : side == TurnSide.derecha
                ? 'Curva derecha'
                : 'Curva',
      };

  String get kindShortEs => kind == RoadKind.recta ? 'Recta' : 'Curva';
}

/// Classify the pilot line into rectas and curvas.
///
/// Pipeline for consistency across riders:
/// 1. Resample by distance (~5 m) so different GPS rates behave alike
/// 2. Label from smoothed heading + lean (stricter than before)
/// 3. Demote weak "curvas" that are really wobble / straight lean
/// 4. Split S-curves (side flip) and double-apex gaps into separate curvas
/// 5. Map indices back onto the original sample list
List<RoadStretch> detectRoadStretches(
  List<TrackPoint> samples, {
  double? neutralLeanDegrees,
  double curvaHeadingDegPerSample = 5.5,
  double rectaHeadingDegPerSample = 1.8,
  double softHeadingDegPerSample = 2.8,
  double leanCurvaDeg = 14,
  double leanSideDeg = 9,
  int minSamples = 4,
  double minDistanceMeters = 18,
  /// Minimum |accumulated heading| for a stretch to stay labeled curva.
  double minCurvaHeadingDeg = 38,
  double resampleStepMeters = 5,
}) {
  if (samples.length < 4) return const [];

  final resampled = _resampleByDistance(samples, stepMeters: resampleStepMeters);
  if (resampled.points.length < 4) {
    return _detectOnSamples(
      samples,
      originalIndex: null,
      neutralLeanDegrees: neutralLeanDegrees,
      curvaHeadingDegPerSample: curvaHeadingDegPerSample,
      rectaHeadingDegPerSample: rectaHeadingDegPerSample,
      softHeadingDegPerSample: softHeadingDegPerSample,
      leanCurvaDeg: leanCurvaDeg,
      leanSideDeg: leanSideDeg,
      minSamples: minSamples,
      minDistanceMeters: minDistanceMeters,
      minCurvaHeadingDeg: minCurvaHeadingDeg,
    );
  }

  return _detectOnSamples(
    resampled.points,
    originalIndex: resampled.originalIndex,
    originalSamples: samples,
    neutralLeanDegrees: neutralLeanDegrees,
    curvaHeadingDegPerSample: curvaHeadingDegPerSample,
    rectaHeadingDegPerSample: rectaHeadingDegPerSample,
    softHeadingDegPerSample: softHeadingDegPerSample,
    leanCurvaDeg: leanCurvaDeg,
    leanSideDeg: leanSideDeg,
    minSamples: minSamples,
    minDistanceMeters: minDistanceMeters,
    minCurvaHeadingDeg: minCurvaHeadingDeg,
  );
}

class _ResampledTrack {
  const _ResampledTrack({
    required this.points,
    required this.originalIndex,
  });

  final List<TrackPoint> points;
  final List<int> originalIndex;
}

_ResampledTrack _resampleByDistance(
  List<TrackPoint> samples, {
  required double stepMeters,
}) {
  if (samples.isEmpty) {
    return const _ResampledTrack(points: [], originalIndex: []);
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
  return _ResampledTrack(points: out, originalIndex: idx);
}

List<RoadStretch> _detectOnSamples(
  List<TrackPoint> samples, {
  List<int>? originalIndex,
  List<TrackPoint>? originalSamples,
  required double? neutralLeanDegrees,
  required double curvaHeadingDegPerSample,
  required double rectaHeadingDegPerSample,
  required double softHeadingDegPerSample,
  required double leanCurvaDeg,
  required double leanSideDeg,
  required int minSamples,
  required double minDistanceMeters,
  required double minCurvaHeadingDeg,
}) {
  final labels = List<RoadKind?>.filled(samples.length, null);
  final sides = List<TurnSide>.filled(samples.length, TurnSide.none);
  final headingDeltas = List<double>.filled(samples.length, 0);
  final leanAbs = List<double>.filled(samples.length, 0);
  final leanSideAt = List<TurnSide>.filled(samples.length, TurnSide.none);
  final rawDelta = List<double>.filled(samples.length, 0);

  double? prevBearing;
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1];
    final b = samples[i];
    final dist = haversineMeters(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );

    final rawLean = b.leanDegrees;
    if (rawLean != null && neutralLeanDegrees != null) {
      final rel = relativeLeanDegrees(
        rawLeanDegrees: rawLean,
        neutralDegrees: neutralLeanDegrees,
      );
      leanAbs[i] = rel.abs();
      if (rel <= -leanSideDeg) {
        leanSideAt[i] = TurnSide.izquierda;
      } else if (rel >= leanSideDeg) {
        leanSideAt[i] = TurnSide.derecha;
      }
    }

    if (dist < 0.5) continue;

    final bearing = _bearingDegrees(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    if (prevBearing == null) {
      prevBearing = bearing;
      continue;
    }
    rawDelta[i] = _signedDeltaDegrees(bearing - prevBearing);
    prevBearing = bearing;
  }

  // Wider smooth window → fewer GPS wobble false curvas on straights.
  for (var i = 1; i < samples.length; i++) {
    var sum = 0.0;
    var n = 0;
    for (var k = math.max(1, i - 3); k <= i; k++) {
      sum += rawDelta[k];
      n++;
    }
    headingDeltas[i] = n == 0 ? 0 : sum / n;
  }

  for (var i = 1; i < samples.length; i++) {
    final dHeading = headingDeltas[i];
    final absH = dHeading.abs();
    final leanA = leanAbs[i];
    final leanSide = leanSideAt[i];

    final strongHeading = absH >= curvaHeadingDegPerSample;
    final softMapPlusLean =
        absH >= softHeadingDegPerSample && leanA >= leanCurvaDeg;
    // Lean alone is NOT enough (straight with pocket lean ≠ curva).
    final committedTurn = absH >= rectaHeadingDegPerSample &&
        leanA >= leanCurvaDeg + 6;

    if (strongHeading || softMapPlusLean || committedTurn) {
      labels[i] = RoadKind.curva;
      sides[i] = _fuseSide(
        dHeading: dHeading,
        leanSide: leanSide,
        absHeading: absH,
        mildHeadingCeil: 6,
      );
    } else if (absH <= rectaHeadingDegPerSample && leanA < leanSideDeg) {
      labels[i] = RoadKind.recta;
      sides[i] = TurnSide.none;
    } else {
      labels[i] = labels[i - 1] ?? RoadKind.recta;
      sides[i] = labels[i] == RoadKind.curva
          ? (sides[i - 1] != TurnSide.none ? sides[i - 1] : leanSide)
          : TurnSide.none;
    }
  }
  labels[0] = labels[1] ?? RoadKind.recta;

  for (var i = 1; i < labels.length - 1; i++) {
    if (labels[i] != labels[i - 1] && labels[i] != labels[i + 1]) {
      labels[i] = labels[i - 1];
      sides[i] = sides[i - 1];
    }
  }

  // Force side-change inside a curva run to start a new stretch (S-curves).
  for (var i = 2; i < labels.length; i++) {
    if (labels[i] == RoadKind.curva &&
        labels[i - 1] == RoadKind.curva &&
        sides[i] != TurnSide.none &&
        sides[i - 1] != TurnSide.none &&
        sides[i] != sides[i - 1]) {
      // Keep label curva; break run by temporarily marking a 1-sample recta.
      labels[i - 1] = RoadKind.recta;
      sides[i - 1] = TurnSide.none;
    }
  }

  final stretches = <RoadStretch>[];
  var start = 0;
  for (var i = 1; i <= samples.length; i++) {
    final endOfRun = i == samples.length || labels[i] != labels[start];
    if (!endOfRun) continue;
    final end = i - 1;
    var kind = labels[start] ?? RoadKind.recta;
    final built = _buildStretch(
      samples: samples,
      start: start,
      end: end,
      kind: kind,
      sides: sides,
      rawDelta: rawDelta,
      leanAbs: leanAbs,
      leanCurvaDeg: leanCurvaDeg,
      leanSideDeg: leanSideDeg,
      minCurvaHeadingDeg: minCurvaHeadingDeg,
      minSamples: minSamples,
      minDistanceMeters: minDistanceMeters,
    );
    if (built != null) stretches.add(built);
    start = i;
  }

  final split = _splitDoubleApexCurvas(
    samples: samples,
    stretches: stretches,
    rawDelta: rawDelta,
    sides: sides,
    leanAbs: leanAbs,
    leanCurvaDeg: leanCurvaDeg,
    leanSideDeg: leanSideDeg,
    minCurvaHeadingDeg: minCurvaHeadingDeg,
    minSamples: minSamples,
    minDistanceMeters: minDistanceMeters,
  );

  // Map resampled indices → original track indices for UI/analytics.
  if (originalIndex == null || originalSamples == null) {
    return split;
  }
  return [
    for (final s in split)
      RoadStretch(
        startIndex: originalIndex[s.startIndex.clamp(0, originalIndex.length - 1)],
        endIndex: originalIndex[s.endIndex.clamp(0, originalIndex.length - 1)],
        kind: s.kind,
        side: s.side,
        distanceMeters: s.distanceMeters,
        duration: s.duration,
        headingChangeDeg: s.headingChangeDeg,
        avgAbsLeanDeg: s.avgAbsLeanDeg,
        peakAbsLeanDeg: s.peakAbsLeanDeg,
        fingerprint: _fingerprintFor(
          originalSamples,
          originalIndex[s.startIndex.clamp(0, originalIndex.length - 1)],
          originalIndex[s.endIndex.clamp(0, originalIndex.length - 1)],
        ),
      ),
  ];
}

RoadStretch? _buildStretch({
  required List<TrackPoint> samples,
  required int start,
  required int end,
  required RoadKind kind,
  required List<TurnSide> sides,
  required List<double> rawDelta,
  required List<double> leanAbs,
  required double leanCurvaDeg,
  required double leanSideDeg,
  required double minCurvaHeadingDeg,
  required int minSamples,
  required double minDistanceMeters,
}) {
  final slice = samples.sublist(start, end + 1);
  final dist = pathDistanceMeters(slice);
  final dur = slice.length < 2
      ? Duration.zero
      : slice.last.timestamp.difference(slice.first.timestamp);

  var headingSum = 0.0;
  var leanAbsSum = 0.0;
  var leanN = 0;
  var peakLean = 0.0;
  var leftVotes = 0;
  var rightVotes = 0;
  for (var j = start; j <= end; j++) {
    headingSum += rawDelta[j];
    if (sides[j] == TurnSide.izquierda) leftVotes++;
    if (sides[j] == TurnSide.derecha) rightVotes++;
    if (leanAbs[j] > 0) {
      leanAbsSum += leanAbs[j];
      leanN++;
      if (leanAbs[j] > peakLean) peakLean = leanAbs[j];
    }
  }
  final avgLean = leanN == 0 ? 0.0 : leanAbsSum / leanN;

  var outKind = kind;
  // Demote: need real heading OR (moderate heading + committed lean).
  if (outKind == RoadKind.curva) {
    final headingOk = headingSum.abs() >= minCurvaHeadingDeg;
    final leanAssisted =
        headingSum.abs() >= minCurvaHeadingDeg * 0.45 &&
            avgLean >= leanCurvaDeg;
    final peakAssisted =
        headingSum.abs() >= 22 && peakLean >= leanCurvaDeg + 4;
    if (!headingOk && !leanAssisted && !peakAssisted) {
      outKind = RoadKind.recta;
    }
  }

  TurnSide side = TurnSide.none;
  if (outKind == RoadKind.curva) {
    if (leftVotes > rightVotes) {
      side = TurnSide.izquierda;
    } else if (rightVotes > leftVotes) {
      side = TurnSide.derecha;
    } else if (headingSum < -1) {
      side = TurnSide.izquierda;
    } else if (headingSum > 1) {
      side = TurnSide.derecha;
    }
  }

  final sampleCount = end - start + 1;
  if (sampleCount < minSamples || dist < minDistanceMeters) {
    return null;
  }

  return RoadStretch(
    startIndex: start,
    endIndex: end,
    kind: outKind,
    side: side,
    distanceMeters: dist,
    duration: dur,
    headingChangeDeg: headingSum,
    avgAbsLeanDeg: avgLean,
    peakAbsLeanDeg: peakLean,
    fingerprint: _fingerprintFor(samples, start, end),
  );
}

/// Split a long curva that contains a low-curvature gap (two corners linked).
List<RoadStretch> _splitDoubleApexCurvas({
  required List<TrackPoint> samples,
  required List<RoadStretch> stretches,
  required List<double> rawDelta,
  required List<TurnSide> sides,
  required List<double> leanAbs,
  required double leanCurvaDeg,
  required double leanSideDeg,
  required double minCurvaHeadingDeg,
  required int minSamples,
  required double minDistanceMeters,
}) {
  final out = <RoadStretch>[];
  for (final s in stretches) {
    if (s.kind != RoadKind.curva || s.endIndex - s.startIndex < 10) {
      out.add(s);
      continue;
    }

    // Find quiet mid gap: |Δheading| low for ≥3 samples after activity.
    var splitAt = -1;
    var quiet = 0;
    final midLo = s.startIndex + 3;
    final midHi = s.endIndex - 3;
    for (var i = midLo; i <= midHi; i++) {
      if (rawDelta[i].abs() < 1.2 && leanAbs[i] < leanSideDeg) {
        quiet++;
        if (quiet >= 3) {
          splitAt = i - 1;
          break;
        }
      } else {
        quiet = 0;
      }
    }

    if (splitAt < 0) {
      out.add(s);
      continue;
    }

    final left = _buildStretch(
      samples: samples,
      start: s.startIndex,
      end: splitAt,
      kind: RoadKind.curva,
      sides: sides,
      rawDelta: rawDelta,
      leanAbs: leanAbs,
      leanCurvaDeg: leanCurvaDeg,
      leanSideDeg: leanSideDeg,
      minCurvaHeadingDeg: minCurvaHeadingDeg * 0.7,
      minSamples: minSamples,
      minDistanceMeters: minDistanceMeters * 0.7,
    );
    final right = _buildStretch(
      samples: samples,
      start: splitAt + 1,
      end: s.endIndex,
      kind: RoadKind.curva,
      sides: sides,
      rawDelta: rawDelta,
      leanAbs: leanAbs,
      leanCurvaDeg: leanCurvaDeg,
      leanSideDeg: leanSideDeg,
      minCurvaHeadingDeg: minCurvaHeadingDeg * 0.7,
      minSamples: minSamples,
      minDistanceMeters: minDistanceMeters * 0.7,
    );

    if (left != null &&
        right != null &&
        left.kind == RoadKind.curva &&
        right.kind == RoadKind.curva) {
      out.add(left);
      out.add(right);
    } else {
      out.add(s);
    }
  }
  return out;
}

String _fingerprintFor(List<TrackPoint> samples, int start, int end) {
  if (samples.isEmpty) return '';
  final lo = start.clamp(0, samples.length - 1);
  final hi = end.clamp(lo, samples.length - 1);
  final mid = samples[((lo + hi) / 2).round()];
  // ~25 m grid at mid-latitudes.
  final gLat = (mid.latitude * 4000).round();
  final gLng = (mid.longitude * 4000).round();
  return '$gLat,$gLng';
}

TurnSide _fuseSide({
  required double dHeading,
  required TurnSide leanSide,
  required double absHeading,
  required double mildHeadingCeil,
}) {
  TurnSide headingSide = TurnSide.none;
  if (dHeading < -0.5) {
    headingSide = TurnSide.izquierda;
  } else if (dHeading > 0.5) {
    headingSide = TurnSide.derecha;
  }

  if (leanSide == TurnSide.none) return headingSide;
  if (headingSide == TurnSide.none) return leanSide;
  if (leanSide == headingSide) return leanSide;
  if (absHeading < mildHeadingCeil) return leanSide;
  return headingSide;
}

double _bearingDegrees(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = _toRad(lat1);
  final phi2 = _toRad(lat2);
  final dLon = _toRad(lon2 - lon1);
  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  return (_toDeg(math.atan2(y, x)) + 360) % 360;
}

double _signedDeltaDegrees(double delta) {
  var d = delta % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

double _toRad(double deg) => deg * math.pi / 180;
double _toDeg(double rad) => rad * 180 / math.pi;
