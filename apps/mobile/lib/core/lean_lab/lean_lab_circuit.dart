import 'dart:math' as math;

import '../models/track_point.dart';
import '../utils/geo_utils.dart';

/// Official Lean Lab test circuit — Bugambilias / Plaza Panorámica (Zapopan).
///
/// Map: https://maps.app.goo.gl/ttgwT6ewv8DKUSQc8
abstract final class BugambiliasCircuit {
  static const protocolId = 'lean_lab_bugambilias_v1';
  static const displayName = 'Bugambilias';
  static const mapsUrl = 'https://maps.app.goo.gl/ttgwT6ewv8DKUSQc8';

  /// Lower end of the linked route.
  static const startLat = 20.6032273;
  static const startLng = -103.4352614;

  /// Plaza Panorámica Bugambilias.
  static const plazaLat = 20.6113781;
  static const plazaLng = -103.4609937;

  /// Loose bbox around the canyon road (both directions).
  static const minLat = 20.598;
  static const maxLat = 20.618;
  static const minLng = -103.470;
  static const maxLng = -103.425;

  static bool contains(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  static bool trackOverlaps(List<TrackPoint> samples, {int minHits = 8}) {
    var hits = 0;
    for (final p in samples) {
      if (contains(p.latitude, p.longitude)) {
        hits++;
        if (hits >= minHits) return true;
      }
    }
    return false;
  }

  /// Fraction of samples inside the circuit bbox (0–1).
  static double coveragePct(List<TrackPoint> samples) {
    if (samples.isEmpty) return 0;
    var hits = 0;
    for (final p in samples) {
      if (contains(p.latitude, p.longitude)) hits++;
    }
    return hits / samples.length;
  }

  /// Infer outbound (toward plaza) vs return from early-path bearing.
  static LeanLabDirection inferDirection(List<TrackPoint> samples) {
    if (samples.length < 5) return LeanLabDirection.unknown;
    final a = samples.first;
    final mid = samples[samples.length ~/ 5];
    final travel = _bearingDeg(
      a.latitude,
      a.longitude,
      mid.latitude,
      mid.longitude,
    );
    final toPlaza = _bearingDeg(
      a.latitude,
      a.longitude,
      plazaLat,
      plazaLng,
    );
    final delta = _angleDiffDeg(travel, toPlaza).abs();
    if (delta < 70) return LeanLabDirection.outbound;
    if (delta > 110) return LeanLabDirection.returnTrip;
    // Fallback: closer to plaza at end → outbound.
    final d0 = haversineMeters(
      samples.first.latitude,
      samples.first.longitude,
      plazaLat,
      plazaLng,
    );
    final d1 = haversineMeters(
      samples.last.latitude,
      samples.last.longitude,
      plazaLat,
      plazaLng,
    );
    if (d1 + 80 < d0) return LeanLabDirection.outbound;
    if (d0 + 80 < d1) return LeanLabDirection.returnTrip;
    return LeanLabDirection.unknown;
  }
}

enum LeanLabDirection {
  outbound,
  returnTrip,
  unknown;

  String get id => switch (this) {
        LeanLabDirection.outbound => 'outbound',
        LeanLabDirection.returnTrip => 'return',
        LeanLabDirection.unknown => 'unknown',
      };

  static LeanLabDirection fromId(String? id) => switch (id) {
        'outbound' => LeanLabDirection.outbound,
        'return' => LeanLabDirection.returnTrip,
        _ => LeanLabDirection.unknown,
      };
}

enum LeanLabSessionType {
  /// Outbound toward plaza, center mount.
  baselineOutbound,

  /// Return from plaza, center mount.
  baselineReturn,

  /// Same stretch, pocket mount (either direction — set direction separately).
  mountPocket,

  /// Free lean lab lap on this circuit.
  free;

  String get id => name;

  static LeanLabSessionType fromId(String? id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return LeanLabSessionType.free;
  }
}

double _bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _angleDiffDeg(double a, double b) {
  var d = (a - b) % 360;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return d;
}
