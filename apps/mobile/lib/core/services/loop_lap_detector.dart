import '../utils/geo_utils.dart';

/// Pure-Dart auto-lap detector for Loop mode.
///
/// Once armed with an init-zone center + geofence radius, feed GPS samples
/// in order. [feed] returns true exactly once per completed lap: the rider
/// must leave the init geofence, then re-enter it after covering at least
/// [minLapDistanceMeters] and at least [minLapDuration] since the lap began.
class LoopLapDetector {
  LoopLapDetector({
    required this.initLat,
    required this.initLng,
    required this.geofenceRadiusM,
    this.minLapDistanceMeters = 200,
    this.minLapDuration = const Duration(seconds: 30),
  });

  final double initLat;
  final double initLng;
  final double geofenceRadiusM;
  final double minLapDistanceMeters;
  final Duration minLapDuration;

  bool _hasExitedZone = false;
  double _distanceSinceLapStart = 0;
  double? _lastLat;
  double? _lastLng;
  DateTime? _lapStartedAt;

  /// Distance accumulated since the current lap started.
  double get distanceSinceLapStart => _distanceSinceLapStart;

  /// (Re)starts lap tracking from [at]. Call once when arming, and again
  /// after each completed lap.
  void startLap(DateTime at) {
    _lapStartedAt = at;
    _hasExitedZone = false;
    _distanceSinceLapStart = 0;
    _lastLat = null;
    _lastLng = null;
  }

  /// Feed a GPS sample. Returns true when a lap just completed.
  bool feed({
    required double lat,
    required double lng,
    required DateTime timestamp,
  }) {
    final lastLat = _lastLat;
    final lastLng = _lastLng;
    if (lastLat != null && lastLng != null) {
      _distanceSinceLapStart += haversineMeters(lastLat, lastLng, lat, lng);
    }
    _lastLat = lat;
    _lastLng = lng;

    final inside = inGeofence(lat, lng, initLat, initLng, geofenceRadiusM);

    if (!_hasExitedZone) {
      if (!inside) _hasExitedZone = true;
      return false;
    }

    if (!inside) return false;

    final startedAt = _lapStartedAt;
    final elapsedOk = startedAt == null ||
        timestamp.difference(startedAt) >= minLapDuration;
    final distanceOk = _distanceSinceLapStart >= minLapDistanceMeters;
    return elapsedOk && distanceOk;
  }
}
