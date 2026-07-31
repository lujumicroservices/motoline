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
  });

  final int startIndex;
  final int endIndex;
  final RoadKind kind;
  final TurnSide side;
  final double distanceMeters;
  final Duration duration;
  final double headingChangeDeg;
  final double avgAbsLeanDeg;

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

/// Classify the pilot line into rectas and curvas using **heading (map line)
/// + lean (inclination)** together.
///
/// - Strong heading change → curva
/// - Mild heading + sustained lean → curva (pocket/mount still counts)
/// - Side: lean preferred when it agrees with heading or heading is mild;
///   otherwise heading wins on conflict
List<RoadStretch> detectRoadStretches(
  List<TrackPoint> samples, {
  double? neutralLeanDegrees,
  double curvaHeadingDegPerSample = 4.5,
  double rectaHeadingDegPerSample = 2.0,
  /// Mild map turn that still becomes curva when lean is strong.
  double softHeadingDegPerSample = 2.5,
  double leanCurvaDeg = 12,
  double leanSideDeg = 8,
  int minSamples = 4,
  double minDistanceMeters = 12,
  /// Minimum |accumulated heading| for a stretch to stay labeled curva.
  double minCurvaHeadingDeg = 22,
}) {
  if (samples.length < 4) return const [];

  final labels = List<RoadKind?>.filled(samples.length, null);
  final sides = List<TurnSide>.filled(samples.length, TurnSide.none);
  final headingDeltas = List<double>.filled(samples.length, 0);
  final leanAbs = List<double>.filled(samples.length, 0);
  final leanSideAt = List<TurnSide>.filled(samples.length, TurnSide.none);

  // Raw per-hop bearings.
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

    if (dist < 0.8) {
      // Keep previous bearing; delta stays 0 — lean drives classification.
      continue;
    }

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

  // Smooth heading delta over a short window.
  for (var i = 1; i < samples.length; i++) {
    var sum = 0.0;
    var n = 0;
    for (var k = math.max(1, i - 2); k <= i; k++) {
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
    final shortHop = rawDelta[i] == 0 && absH < 0.01;

    final strongHeading = absH >= curvaHeadingDegPerSample;
    final softMapPlusLean =
        absH >= softHeadingDegPerSample && leanA >= leanCurvaDeg;
    final leanDominant = leanA >= leanCurvaDeg + 4 &&
        (absH >= rectaHeadingDegPerSample || shortHop);

    if (strongHeading || softMapPlusLean || leanDominant) {
      labels[i] = RoadKind.curva;
      sides[i] = _fuseSide(
        dHeading: dHeading,
        leanSide: leanSide,
        absHeading: absH,
        mildHeadingCeil: 7,
      );
    } else if (absH <= rectaHeadingDegPerSample && leanA < leanSideDeg) {
      labels[i] = RoadKind.recta;
      sides[i] = TurnSide.none;
    } else {
      final prev = labels[i - 1] ?? RoadKind.recta;
      if (leanA >= leanCurvaDeg &&
          (absH >= softHeadingDegPerSample * 0.8 || shortHop)) {
        labels[i] = RoadKind.curva;
        sides[i] = _fuseSide(
          dHeading: dHeading,
          leanSide: leanSide,
          absHeading: absH,
          mildHeadingCeil: 7,
        );
      } else {
        labels[i] = prev;
        sides[i] = labels[i] == RoadKind.curva
            ? (sides[i - 1] != TurnSide.none
                ? sides[i - 1]
                : leanSide)
            : TurnSide.none;
      }
    }
  }
  labels[0] = labels[1] ?? RoadKind.recta;

  // Smooth single-sample flips.
  for (var i = 1; i < labels.length - 1; i++) {
    if (labels[i] != labels[i - 1] && labels[i] != labels[i + 1]) {
      labels[i] = labels[i - 1];
      sides[i] = sides[i - 1];
    }
  }

  final stretches = <RoadStretch>[];
  var start = 0;
  for (var i = 1; i <= samples.length; i++) {
    final endOfRun = i == samples.length || labels[i] != labels[start];
    if (!endOfRun) continue;
    final end = i - 1;
    var kind = labels[start] ?? RoadKind.recta;
    final slice = samples.sublist(start, end + 1);
    final dist = pathDistanceMeters(slice);
    final dur = slice.length < 2
        ? Duration.zero
        : slice.last.timestamp.difference(slice.first.timestamp);

    var headingSum = 0.0;
    var leanAbsSum = 0.0;
    var leanN = 0;
    var leftVotes = 0;
    var rightVotes = 0;
    for (var j = start; j <= end; j++) {
      headingSum += rawDelta[j];
      if (sides[j] == TurnSide.izquierda) leftVotes++;
      if (sides[j] == TurnSide.derecha) rightVotes++;
      if (leanAbs[j] > 0) {
        leanAbsSum += leanAbs[j];
        leanN++;
      }
    }

    final avgLean = leanN == 0 ? 0.0 : leanAbsSum / leanN;

    // Demote weak "curvas" that never accumulated real turn or lean.
    if (kind == RoadKind.curva &&
        headingSum.abs() < minCurvaHeadingDeg &&
        avgLean < leanCurvaDeg) {
      kind = RoadKind.recta;
    }

    TurnSide side = TurnSide.none;
    if (kind == RoadKind.curva) {
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
    if (sampleCount >= minSamples && dist >= minDistanceMeters) {
      stretches.add(
        RoadStretch(
          startIndex: start,
          endIndex: end,
          kind: kind,
          side: side,
          distanceMeters: dist,
          duration: dur,
          headingChangeDeg: headingSum,
          avgAbsLeanDeg: avgLean,
        ),
      );
    } else if (stretches.isNotEmpty) {
      // Merge tiny leftovers — recompute kind on the merged window.
      final prev = stretches.removeLast();
      final mergedStart = prev.startIndex;
      final mergedEnd = end;
      var mergedHeading = 0.0;
      var mergedLean = 0.0;
      var mergedLeanN = 0;
      var mLeft = 0;
      var mRight = 0;
      for (var j = mergedStart; j <= mergedEnd; j++) {
        mergedHeading += rawDelta[j];
        if (sides[j] == TurnSide.izquierda) mLeft++;
        if (sides[j] == TurnSide.derecha) mRight++;
        if (leanAbs[j] > 0) {
          mergedLean += leanAbs[j];
          mergedLeanN++;
        }
      }
      final mergedAvgLean =
          mergedLeanN == 0 ? 0.0 : mergedLean / mergedLeanN;
      var mergedKind = prev.kind;
      if (mergedHeading.abs() >= minCurvaHeadingDeg ||
          mergedAvgLean >= leanCurvaDeg) {
        mergedKind = RoadKind.curva;
      } else if (mergedHeading.abs() < minCurvaHeadingDeg * 0.5 &&
          mergedAvgLean < leanSideDeg) {
        mergedKind = RoadKind.recta;
      }
      TurnSide mergedSide = TurnSide.none;
      if (mergedKind == RoadKind.curva) {
        if (mLeft > mRight) {
          mergedSide = TurnSide.izquierda;
        } else if (mRight > mLeft) {
          mergedSide = TurnSide.derecha;
        } else if (mergedHeading < -1) {
          mergedSide = TurnSide.izquierda;
        } else if (mergedHeading > 1) {
          mergedSide = TurnSide.derecha;
        }
      }
      stretches.add(
        RoadStretch(
          startIndex: mergedStart,
          endIndex: mergedEnd,
          kind: mergedKind,
          side: mergedSide,
          distanceMeters: pathDistanceMeters(
            samples.sublist(mergedStart, mergedEnd + 1),
          ),
          duration: samples[mergedEnd]
              .timestamp
              .difference(samples[mergedStart].timestamp),
          headingChangeDeg: mergedHeading,
          avgAbsLeanDeg: mergedAvgLean,
        ),
      );
    }

    start = i;
  }

  return stretches;
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
  // Conflict: trust lean when map heading is mild; else map line.
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
