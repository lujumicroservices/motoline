import 'dart:math' as math;

import '../models/lean_sample.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'lean_neutral.dart';
import 'road_kind_detection.dart';

/// WGS84 point on a matched (or GPS) centerline.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// One corner found on a centerline by discrete curvature + hysteresis.
class MapCurve {
  const MapCurve({
    required this.startIndex,
    required this.apexIndex,
    required this.endIndex,
    required this.poly,
    required this.headingChangeDeg,
    required this.radiusM,
    required this.lengthM,
    required this.side,
    required this.fromMapMatch,
    required this.mapApex,
    required this.entryS,
    required this.apexS,
    required this.exitS,
  });

  final int startIndex;
  final int apexIndex;
  final int endIndex;
  final List<GeoPoint> poly;
  final double headingChangeDeg;
  final double radiusM;
  final double lengthM;
  final TurnSide side;
  final bool fromMapMatch;
  final GeoPoint mapApex;
  final double entryS;
  final double apexS;
  final double exitS;
}

/// GPS/IMU measurements for one [MapCurve].
class MapCurveRider {
  const MapCurveRider({
    required this.curve,
    required this.entryIndex,
    required this.exitIndex,
    required this.riderApexIndex,
    required this.entrySpeedKmh,
    required this.apexSpeedKmh,
    required this.exitSpeedKmh,
    required this.maxLeanDegrees,
    this.riderLeanDegrees,
    this.riderKmh,
    this.apexGapAlongM,
    this.timing,
  });

  final MapCurve curve;
  final int entryIndex;
  final int exitIndex;
  final int riderApexIndex;
  final double entrySpeedKmh;
  final double apexSpeedKmh;
  final double exitSpeedKmh;
  final double maxLeanDegrees;
  final double? riderLeanDegrees;
  final double? riderKmh;
  final double? apexGapAlongM;
  final String? timing;
}

/// Curvature (κ = Δθ / Δs) detector with radius hysteresis.
class MapCurveEngine {
  const MapCurveEngine({
    this.resampleStepM = 8,
    this.enterRadiusM = 120,
    this.exitRadiusM = 220,
    this.sharpHeadingDeg = 25,
    this.minTurnDeg = 35,
    this.minLengthM = 16,
    this.maxLengthM = 400,
    this.quietSamplesToExit = 3,
    this.riderMinKmh = 18,
  });

  final double resampleStepM;
  final double enterRadiusM;
  final double exitRadiusM;
  final double sharpHeadingDeg;
  final double minTurnDeg;
  final double minLengthM;
  final double maxLengthM;
  final int quietSamplesToExit;
  final double riderMinKmh;

  /// Detect corners on [centerline] (matched road axis, or GPS fallback).
  List<MapCurve> detect({
    required List<GeoPoint> centerline,
    required bool fromMapMatch,
  }) {
    final rs = resample(centerline, resampleStepM);
    if (rs.length < 4) return const [];

    final n = rs.length;
    final dHeading = List<double>.filled(n, 0);
    final radius = List<double>.filled(n, 1e9);
    final s = cumulativeS(rs);

    for (var i = 1; i < n - 1; i++) {
      final dIn = haversineMeters(rs[i - 1].lat, rs[i - 1].lng, rs[i].lat, rs[i].lng);
      final dOut = haversineMeters(rs[i].lat, rs[i].lng, rs[i + 1].lat, rs[i + 1].lng);
      if (dIn < 2 || dOut < 2) continue;
      final brIn = bearingDegrees(rs[i - 1].lat, rs[i - 1].lng, rs[i].lat, rs[i].lng);
      final brOut = bearingDegrees(rs[i].lat, rs[i].lng, rs[i + 1].lat, rs[i + 1].lng);
      final dh = signedDeltaDegrees(brOut - brIn);
      dHeading[i] = dh;
      final ds = (dIn + dOut) / 2;
      final rad = dh.abs() * math.pi / 180;
      radius[i] = rad > 1e-6 ? ds / rad : 1e9;
    }

    final inCurve = List<bool>.filled(n, false);
    for (var i = 1; i < n - 1; i++) {
      final sharp = dHeading[i].abs() >= sharpHeadingDeg;
      final tight = radius[i] <= enterRadiusM;
      final moderate = radius[i] <= 180 && dHeading[i].abs() >= 8;
      inCurve[i] = sharp || tight || moderate;
    }

    final curves = <MapCurve>[];
    var i = 1;
    while (i < n - 1) {
      if (!inCurve[i]) {
        i++;
        continue;
      }
      final start = i;
      var quiet = 0;
      var j = i;
      while (j < n - 1) {
        final exiting = radius[j] > exitRadiusM && dHeading[j].abs() < 12;
        if (!inCurve[j] || exiting) {
          quiet++;
          if (quiet >= quietSamplesToExit) break;
        } else {
          quiet = 0;
        }
        j++;
      }
      final end = j.clamp(start, n - 2);
      i = j + 1;

      final parts = splitByHeadingSign(
        dHeading: dHeading,
        start: start,
        end: end,
        minTurnDeg: minTurnDeg,
      );
      for (final part in parts) {
        final built = buildCurve(
          rs: rs,
          s: s,
          dHeading: dHeading,
          radius: radius,
          start: part.$1,
          end: part.$2,
          fromMapMatch: fromMapMatch,
        );
        if (built != null) curves.add(built);
      }
    }
    return curves;
  }

  MapCurve? buildCurve({
    required List<GeoPoint> rs,
    required List<double> s,
    required List<double> dHeading,
    required List<double> radius,
    required int start,
    required int end,
    required bool fromMapMatch,
  }) {
    final n = rs.length;
    var heading = 0.0;
    var minR = 1e9;
    var apex = start;
    for (var k = start; k <= end; k++) {
      heading += dHeading[k];
      if (radius[k] < minR) {
        minR = radius[k];
        apex = k;
      }
    }
    final lo = math.max(0, start - 2);
    final hi = math.min(n - 1, end + 2);
    final poly = rs.sublist(lo, hi + 1);
    final length = s[hi] - s[lo];
    if (heading.abs() < minTurnDeg) return null;
    if (length < minLengthM || length > maxLengthM) return null;
    if (hi - lo < 3) return null;
    return MapCurve(
      startIndex: 0,
      apexIndex: apex - lo,
      endIndex: poly.length - 1,
      poly: poly,
      headingChangeDeg: heading,
      radiusM: minR.isFinite
          ? minR
          : length / math.max(heading.abs() * math.pi / 180, 1e-3),
      lengthM: length,
      side: heading < 0 ? TurnSide.izquierda : TurnSide.derecha,
      fromMapMatch: fromMapMatch,
      mapApex: rs[apex],
      entryS: 0,
      apexS: s[apex] - s[lo],
      exitS: s[hi] - s[lo],
    );
  }

  /// Bind GPS/IMU samples to a detected map (or GPS-geometry) curve.
  MapCurveRider? attachRider({
    required MapCurve curve,
    required List<TrackPoint> samples,
    required double neutralLeanDegrees,
    List<LeanSample> leanSamples = const [],
  }) {
    if (samples.length < 3) return null;
    final hits = <int>[];
    final hitS = <double>[];
    for (var i = 0; i < samples.length; i++) {
      final p = samples[i];
      final proj = projectOntoPoly(GeoPoint(p.latitude, p.longitude), curve.poly);
      if (proj == null) continue;
      if (proj.distM > 40) continue;
      if (proj.sM < curve.entryS - 20 || proj.sM > curve.exitS + 20) continue;
      hits.add(i);
      hitS.add(proj.sM);
    }
    if (hits.length < 3) return null;

    // One pass through the corner — not every time the rider came near it.
    final visit = pickCornerVisit(
      samples: samples,
      hits: hits,
      hitS: hitS,
      apexS: curve.apexS,
    );
    final visitHits = [for (var h = visit.$1; h <= visit.$2; h++) hits[h]];
    final visitS = [for (var h = visit.$1; h <= visit.$2; h++) hitS[h]];
    if (visitHits.length < 3) return null;

    final entryIndex = visitHits.first;
    final exitIndex = visitHits.last;
    final wantLeft = curve.headingChangeDeg < 0;

    var riderApexIndex = ((entryIndex + exitIndex) / 2).round();
    var bestScore = -1.0;
    double? riderLean;
    double? riderKmh;
    double? riderS;

    void consider(int i, double lean, double kmh, double? alongS, {bool allowSlow = false}) {
      if (!allowSlow && kmh < riderMinKmh) return;
      final match = (lean < 0) == wantLeft;
      final score = match ? lean.abs() : lean.abs() * 0.2;
      if (score > bestScore) {
        bestScore = score;
        riderApexIndex = i;
        riderLean = lean;
        riderKmh = kmh;
        riderS = alongS;
      }
    }

    for (var h = 0; h < visitHits.length; h++) {
      final i = visitHits[h];
      final raw = samples[i].leanDegrees;
      if (raw == null) continue;
      final lean = relativeLeanDegrees(
        rawLeanDegrees: raw,
        neutralDegrees: neutralLeanDegrees,
      );
      consider(i, lean, samples[i].speedKmh ?? 0, visitS[h]);
    }

    if (leanSamples.isNotEmpty) {
      final t0 = samples[entryIndex].timestamp.millisecondsSinceEpoch;
      final t1 = samples[exitIndex].timestamp.millisecondsSinceEpoch;
      for (final ls in leanSamples) {
        if (ls.timestampMs < t0 || ls.timestampMs > t1) continue;
        final lean = relativeLeanDegrees(
          rawLeanDegrees: ls.leanDegrees,
          neutralDegrees: neutralLeanDegrees,
        );
        final idx = _nearestIndexByMs(samples, ls.timestampMs)
            .clamp(entryIndex, exitIndex);
        final kmh = samples[idx].speedKmh ?? 0;
        final proj = projectOntoPoly(
          GeoPoint(samples[idx].latitude, samples[idx].longitude),
          curve.poly,
        );
        consider(idx, lean, kmh, proj?.sM);
      }
    }

    if (riderLean == null) {
      for (var h = 0; h < visitHits.length; h++) {
        final i = visitHits[h];
        final raw = samples[i].leanDegrees;
        if (raw == null) continue;
        final lean = relativeLeanDegrees(
          rawLeanDegrees: raw,
          neutralDegrees: neutralLeanDegrees,
        );
        consider(i, lean, samples[i].speedKmh ?? 0, visitS[h], allowSlow: true);
      }
    }

    var maxLean = 0.0;
    for (final i in visitHits) {
      final raw = samples[i].leanDegrees;
      if (raw == null) continue;
      final lean = relativeLeanDegrees(
        rawLeanDegrees: raw,
        neutralDegrees: neutralLeanDegrees,
      ).abs();
      if (lean > maxLean) maxLean = lean;
    }
    if (riderLean != null && riderLean!.abs() > maxLean) {
      maxLean = riderLean!.abs();
    }

    double? gap;
    String? timing;
    if (riderS != null) {
      gap = riderS! - curve.apexS;
      if (gap < -8) {
        timing = 'antes';
      } else if (gap > 8) {
        timing = 'despues';
      } else {
        timing = 'cerca';
      }
    }

    double speedAt(int i) {
      final s = samples[i].speedKmh;
      if (s != null) return s;
      for (var d = 1; d < 5; d++) {
        if (i - d >= 0 && samples[i - d].speedKmh != null) {
          return samples[i - d].speedKmh!;
        }
        if (i + d < samples.length && samples[i + d].speedKmh != null) {
          return samples[i + d].speedKmh!;
        }
      }
      return 0;
    }

    return MapCurveRider(
      curve: curve,
      entryIndex: entryIndex,
      exitIndex: exitIndex,
      riderApexIndex: riderApexIndex.clamp(entryIndex, exitIndex),
      entrySpeedKmh: speedAt(entryIndex),
      apexSpeedKmh: speedAt(riderApexIndex.clamp(0, samples.length - 1)),
      exitSpeedKmh: speedAt(exitIndex),
      maxLeanDegrees: maxLean,
      riderLeanDegrees: riderLean,
      riderKmh: riderKmh,
      apexGapAlongM: gap,
      timing: timing,
    );
  }
}

/// Split a hysteresis blob where the rider (or street) turns left then right.
List<(int, int)> splitByHeadingSign({
  required List<double> dHeading,
  required int start,
  required int end,
  required double minTurnDeg,
}) {
  if (end <= start) return [(start, end)];
  final parts = <(int, int)>[];
  var a = start;
  var acc = 0.0;
  var sign = 0;
  for (var k = start; k <= end; k++) {
    final dh = dHeading[k];
    final s = dh.abs() < 3 ? 0 : (dh < 0 ? -1 : 1);
    if (sign != 0 && s != 0 && s != sign && acc.abs() >= minTurnDeg) {
      parts.add((a, k - 1));
      a = k;
      acc = dh;
      sign = s;
    } else {
      acc += dh;
      if (sign == 0 && s != 0) sign = s;
    }
  }
  parts.add((a, end));
  return parts;
}

/// Among GPS hits on a corner, keep the single pass nearest the map apex.
(int, int) pickCornerVisit({
  required List<TrackPoint> samples,
  required List<int> hits,
  required List<double> hitS,
  required double apexS,
}) {
  if (hits.isEmpty) return (0, 0);
  final visits = <(int, int)>[];
  var a = 0;
  for (var h = 1; h < hits.length; h++) {
    final dt = samples[hits[h]]
        .timestamp
        .difference(samples[hits[h - 1]].timestamp)
        .inMilliseconds;
    final ds = hitS[h] - hitS[h - 1];
    final newLap = dt > 8000 || hits[h] - hits[h - 1] > 8 || ds < -25;
    if (newLap) {
      visits.add((a, h - 1));
      a = h;
    }
  }
  visits.add((a, hits.length - 1));

  var best = visits.first;
  var bestD = 1e9;
  var bestLean = -1.0;
  for (final v in visits) {
    var d = 1e9;
    var lean = 0.0;
    for (var h = v.$1; h <= v.$2; h++) {
      final x = (hitS[h] - apexS).abs();
      if (x < d) d = x;
      final raw = samples[hits[h]].leanDegrees;
      if (raw != null && raw.abs() > lean) lean = raw.abs();
    }
    final closer = d < bestD - 8;
    final samePlace = (d - bestD).abs() <= 8;
    if (closer || (samePlace && lean >= bestLean)) {
      bestD = d;
      bestLean = lean;
      best = v;
    }
  }
  return best;
}

/// GPS points as a fallback centerline (no street axis).
List<GeoPoint> gpsCenterline(List<TrackPoint> samples) => [
      for (final p in samples) GeoPoint(p.latitude, p.longitude),
    ];

List<GeoPoint> resample(List<GeoPoint> pts, double stepM) {
  if (pts.length < 2 || stepM <= 0) return List<GeoPoint>.from(pts);
  final out = <GeoPoint>[pts.first];
  var acc = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1];
    final b = pts[i];
    final seg = haversineMeters(a.lat, a.lng, b.lat, b.lng);
    if (seg < 1e-9) continue;
    var consumed = 0.0;
    while (acc + (seg - consumed) >= stepM) {
      final need = stepM - acc;
      consumed += need;
      final t = (consumed / seg).clamp(0.0, 1.0);
      out.add(
        GeoPoint(
          a.lat + (b.lat - a.lat) * t,
          a.lng + (b.lng - a.lng) * t,
        ),
      );
      acc = 0;
    }
    acc += seg - consumed;
  }
  final last = pts.last;
  if (out.last.lat != last.lat || out.last.lng != last.lng) {
    out.add(last);
  }
  return out;
}

int _nearestIndexByMs(List<TrackPoint> samples, int ms) {
  var best = 0;
  var bestD = 1 << 30;
  for (var i = 0; i < samples.length; i++) {
    final d = (samples[i].timestamp.millisecondsSinceEpoch - ms).abs();
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

List<double> cumulativeS(List<GeoPoint> pts) {
  final s = List<double>.filled(pts.length, 0);
  for (var i = 1; i < pts.length; i++) {
    s[i] = s[i - 1] +
        haversineMeters(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
  }
  return s;
}

double signedDeltaDegrees(double delta) {
  var d = delta % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}

({double distM, double sM, GeoPoint xy})? projectOntoPoly(
  GeoPoint p,
  List<GeoPoint> poly,
) {
  if (poly.length < 2) return null;
  var bestD = 1e9;
  var bestS = 0.0;
  var bestXy = poly.first;
  var prefix = 0.0;
  for (var i = 1; i < poly.length; i++) {
    final a = poly[i - 1];
    final b = poly[i];
    final seg = haversineMeters(a.lat, a.lng, b.lat, b.lng);
    final pr = pointToSegment(p, a, b);
    if (pr.distM < bestD) {
      bestD = pr.distM;
      bestS = prefix + pr.t * seg;
      bestXy = pr.xy;
    }
    prefix += seg;
  }
  return (distM: bestD, sM: bestS, xy: bestXy);
}

({double distM, double t, GeoPoint xy}) pointToSegment(
  GeoPoint p,
  GeoPoint a,
  GeoPoint b,
) {
  final lat0 = ((a.lat + b.lat + p.lat) / 3) * math.pi / 180;
  const earth = 6371000.0;
  final kx = earth * math.cos(lat0) * math.pi / 180;
  final ky = earth * math.pi / 180;
  final ax = a.lng * kx;
  final ay = a.lat * ky;
  final bx = b.lng * kx;
  final by = b.lat * ky;
  final px = p.lng * kx;
  final py = p.lat * ky;
  final vx = bx - ax;
  final vy = by - ay;
  final mag2 = vx * vx + vy * vy;
  var t = 0.0;
  var cx = ax;
  var cy = ay;
  if (mag2 >= 1e-6) {
    t = ((px - ax) * vx + (py - ay) * vy) / mag2;
    t = t.clamp(0.0, 1.0);
    cx = ax + t * vx;
    cy = ay + t * vy;
  }
  final dx = px - cx;
  final dy = py - cy;
  return (
    distM: math.sqrt(dx * dx + dy * dy),
    t: t,
    xy: GeoPoint(cy / ky, cx / kx),
  );
}

String mapCurveFingerprint(GeoPoint apex) {
  final gLat = (apex.lat * 4000).round();
  final gLng = (apex.lng * 4000).round();
  return '$gLat,$gLng';
}

/// GPS vertices while moving — Skill Lab fallback when map-match is missing.
List<GeoPoint> movingCenterline(
  List<TrackPoint> samples, {
  double minKmh = 18,
}) {
  if (samples.length < 2) return const [];
  final out = <GeoPoint>[];
  for (var i = 0; i < samples.length; i++) {
    final p = samples[i];
    final kmh = p.speedKmh;
    if (kmh != null) {
      if (kmh >= minKmh) out.add(GeoPoint(p.latitude, p.longitude));
      continue;
    }
    if (out.isEmpty) {
      out.add(GeoPoint(p.latitude, p.longitude));
      continue;
    }
    final prev = samples[i - 1];
    final d = haversineMeters(
      prev.latitude,
      prev.longitude,
      p.latitude,
      p.longitude,
    );
    final dt = p.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (dt <= 0) continue;
    if ((d / dt) * 3.6 >= minKmh) {
      out.add(GeoPoint(p.latitude, p.longitude));
    }
  }
  return out;
}

/// Drop moving GPS to ~[stepM] so the match payload stays small.
List<GeoPoint> decimateTrack(
  List<TrackPoint> samples, {
  double stepM = 18,
  double minKmh = 18,
}) {
  final moving = <TrackPoint>[];
  for (var i = 0; i < samples.length; i++) {
    final p = samples[i];
    final kmh = p.speedKmh;
    if (kmh != null && kmh < minKmh) continue;
    if (kmh == null && moving.isNotEmpty) {
      final prev = moving.last;
      final d = haversineMeters(
        prev.latitude,
        prev.longitude,
        p.latitude,
        p.longitude,
      );
      final dt =
          p.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dt > 0 && (d / dt) * 3.6 < minKmh) continue;
    }
    moving.add(p);
  }
  if (moving.isEmpty) return const [];
  final out = <GeoPoint>[
    GeoPoint(moving.first.latitude, moving.first.longitude),
  ];
  var acc = 0.0;
  for (var i = 1; i < moving.length; i++) {
    final a = moving[i - 1];
    final b = moving[i];
    acc += haversineMeters(a.latitude, a.longitude, b.latitude, b.longitude);
    if (acc >= stepM) {
      out.add(GeoPoint(b.latitude, b.longitude));
      acc = 0;
    }
  }
  final last = moving.last;
  if (out.last.lat != last.latitude || out.last.lng != last.longitude) {
    out.add(GeoPoint(last.latitude, last.longitude));
  }
  return out;
}
