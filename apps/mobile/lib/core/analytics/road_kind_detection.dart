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

/// Classify the pilot line into rectas and curvas from GPS heading change
/// (lean used as a soft vote for turn side).
List<RoadStretch> detectRoadStretches(
  List<TrackPoint> samples, {
  double? neutralLeanDegrees,
  double curvaHeadingDegPerSample = 4.5,
  double rectaHeadingDegPerSample = 2.0,
  int minSamples = 4,
  double minDistanceMeters = 12,
}) {
  if (samples.length < 4) return const [];

  final labels = List<RoadKind?>.filled(samples.length, null);
  final sides = List<TurnSide>.filled(samples.length, TurnSide.none);
  final headingDeltas = List<double>.filled(samples.length, 0);

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
    if (dist < 0.8) {
      labels[i] = labels[i - 1] ?? RoadKind.recta;
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
      labels[i] = RoadKind.recta;
      continue;
    }

    final dHeading = _signedDeltaDegrees(bearing - prevBearing);
    prevBearing = bearing;
    headingDeltas[i] = dHeading;
    final absH = dHeading.abs();

    // Soft lean vote for side (when available).
    TurnSide leanSide = TurnSide.none;
    final rawLean = b.leanDegrees;
    if (rawLean != null && neutralLeanDegrees != null) {
      final rel = relativeLeanDegrees(
        rawLeanDegrees: rawLean,
        neutralDegrees: neutralLeanDegrees,
      );
      if (rel <= -8) {
        leanSide = TurnSide.izquierda;
      } else if (rel >= 8) {
        leanSide = TurnSide.derecha;
      }
    }

    if (absH >= curvaHeadingDegPerSample) {
      labels[i] = RoadKind.curva;
      if (dHeading < 0) {
        sides[i] = TurnSide.izquierda;
      } else if (dHeading > 0) {
        sides[i] = TurnSide.derecha;
      }
      if (leanSide != TurnSide.none) {
        // Prefer lean when it agrees or heading is mild.
        sides[i] = leanSide;
      }
    } else if (absH <= rectaHeadingDegPerSample) {
      labels[i] = RoadKind.recta;
      sides[i] = TurnSide.none;
    } else {
      // Hysteresis band — keep previous label.
      labels[i] = labels[i - 1] ?? RoadKind.recta;
      sides[i] = labels[i] == RoadKind.curva
          ? (sides[i - 1] != TurnSide.none
              ? sides[i - 1]
              : leanSide)
          : TurnSide.none;
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
    final kind = labels[start] ?? RoadKind.recta;
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
      headingSum += headingDeltas[j];
      if (sides[j] == TurnSide.izquierda) leftVotes++;
      if (sides[j] == TurnSide.derecha) rightVotes++;
      final raw = samples[j].leanDegrees;
      if (raw != null && neutralLeanDegrees != null) {
        leanAbsSum += relativeLeanDegrees(
          rawLeanDegrees: raw,
          neutralDegrees: neutralLeanDegrees,
        ).abs();
        leanN++;
      }
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

    if (end - start + 1 >= minSamples && dist >= minDistanceMeters) {
      stretches.add(
        RoadStretch(
          startIndex: start,
          endIndex: end,
          kind: kind,
          side: side,
          distanceMeters: dist,
          duration: dur,
          headingChangeDeg: headingSum,
          avgAbsLeanDeg: leanN == 0 ? 0 : leanAbsSum / leanN,
        ),
      );
    } else if (stretches.isNotEmpty) {
      // Merge tiny leftovers into previous stretch.
      final prev = stretches.removeLast();
      stretches.add(
        RoadStretch(
          startIndex: prev.startIndex,
          endIndex: end,
          kind: prev.kind,
          side: prev.side,
          distanceMeters: pathDistanceMeters(
            samples.sublist(prev.startIndex, end + 1),
          ),
          duration: samples[end]
              .timestamp
              .difference(samples[prev.startIndex].timestamp),
          headingChangeDeg: prev.headingChangeDeg + headingSum,
          avgAbsLeanDeg: prev.avgAbsLeanDeg,
        ),
      );
    }

    start = i;
  }

  return stretches;
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
