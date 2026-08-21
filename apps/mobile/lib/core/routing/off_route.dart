import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../utils/geo_utils.dart';

/// Distance from [point] to the closest segment of [line] (meters).
double distanceToPolylineMeters(LatLng point, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) {
    return haversineMeters(
      point.latitude,
      point.longitude,
      line.first.latitude,
      line.first.longitude,
    );
  }
  var best = double.infinity;
  for (var i = 1; i < line.length; i++) {
    final d = distancePointToSegmentMeters(point, line[i - 1], line[i]);
    if (d < best) best = d;
  }
  return best;
}

/// Equirectangular local-meters projection of [p] onto segment [a]–[b].
double distancePointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(p.latitude * math.pi / 180);
  final ax = (a.longitude - p.longitude) * mPerDegLng;
  final ay = (a.latitude - p.latitude) * mPerDegLat;
  final bx = (b.longitude - p.longitude) * mPerDegLng;
  final by = (b.latitude - p.latitude) * mPerDegLat;
  final abx = bx - ax;
  final aby = by - ay;
  final abLen2 = abx * abx + aby * aby;
  if (abLen2 < 1e-6) {
    return math.sqrt(ax * ax + ay * ay);
  }
  var t = (-ax * abx + -ay * aby) / abLen2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * abx;
  final cy = ay + t * aby;
  return math.sqrt(cx * cx + cy * cy);
}

/// Off-route after staying beyond [thresholdM] for [hold]; clears immediately
/// when back inside the corridor.
class OffRouteTracker {
  OffRouteTracker({
    this.thresholdM = 100,
    this.hold = const Duration(seconds: 15),
  });

  final double thresholdM;
  final Duration hold;

  bool _off = false;
  DateTime? _outsideSince;

  bool get isOffRoute => _off;

  bool update({required double distanceM, required DateTime now}) {
    if (distanceM > thresholdM) {
      _outsideSince ??= now;
      if (!_off && now.difference(_outsideSince!) >= hold) {
        _off = true;
      }
    } else {
      _outsideSince = null;
      _off = false;
    }
    return _off;
  }

  void reset() {
    _off = false;
    _outsideSince = null;
  }
}
