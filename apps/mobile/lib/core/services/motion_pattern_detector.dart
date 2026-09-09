import 'dart:math' as math;

import '../utils/geo_utils.dart';

/// Coarse motion phase — informational only, derived from the same
/// thresholds used to drive pause/resume/suggest-end/auto-start.
enum MotionPhase { idle, moving, stopped }

/// Pure-Dart, side-effect-free motion pattern detector for auto-ride
/// features (auto-pause/resume, suggest-end, arm+auto-start).
///
/// Feed GPS samples in as they arrive; read [isPaused] / [suggestEnd] /
/// [pausedFor] after each call to [feedRideSample], or call
/// [feedArmedSample] while armed and waiting for the ride to begin.
///
/// No Flutter / plugin dependencies — safe to unit test with plain Dart.
class MotionPatternDetector {
  MotionPatternDetector({
    this.pauseSpeedThresholdMps = 2.2, // ~8 km/h
    this.pauseAfter = const Duration(seconds: 12),
    this.resumeSpeedThresholdMps = 3.33, // ~12 km/h
    this.resumeAfter = const Duration(seconds: 3),
    this.resumeDistanceMeters = 15,
    this.suggestEndSpeedThresholdMps = 1.39, // ~5 km/h
    this.suggestEndAfter = const Duration(minutes: 10),
    this.suggestEndDistanceMeters = 25,
    this.autoStartSpeedThresholdMps = 5.56, // ~20 km/h
    this.autoStartAfter = const Duration(seconds: 8),
    this.autoStartDistanceMeters = 80,
  });

  // Auto-pause.
  final double pauseSpeedThresholdMps;
  final Duration pauseAfter;

  // Auto-resume.
  final double resumeSpeedThresholdMps;
  final Duration resumeAfter;
  final double resumeDistanceMeters;

  // Suggest-end (near-stationary for a long time).
  final double suggestEndSpeedThresholdMps;
  final Duration suggestEndAfter;
  final double suggestEndDistanceMeters;

  // Arm -> auto-start.
  final double autoStartSpeedThresholdMps;
  final Duration autoStartAfter;
  final double autoStartDistanceMeters;

  /// When false, ride samples never auto-pause / auto-resume (manual recording).
  bool autoPauseEnabled = true;

  bool _isPaused = false;
  DateTime? _slowSince;
  DateTime? _fastSince;
  DateTime? _pausedAt;
  double? _pauseAnchorLat;
  double? _pauseAnchorLng;

  bool _suggestEnd = false;
  DateTime? _stillSince;
  double? _stillAnchorLat;
  double? _stillAnchorLng;

  DateTime? _fastSinceArm;
  double? _armLastLat;
  double? _armLastLng;
  double _armCumulativeMeters = 0;

  double? _lastLat;
  double? _lastLng;
  DateTime? _lastTs;

  bool get isPaused => _isPaused;
  bool get suggestEnd => _suggestEnd;

  /// How long the ride has been auto-paused, or null when not paused.
  /// [now] defaults to [DateTime.now] but can be injected for tests.
  Duration? pausedFor([DateTime? now]) {
    final pausedAt = _pausedAt;
    if (!_isPaused || pausedAt == null) return null;
    return (now ?? DateTime.now()).difference(pausedAt);
  }

  MotionPhase get phase {
    if (_isPaused) return MotionPhase.stopped;
    return MotionPhase.moving;
  }

  /// Reset all state for a freshly started (or resumed) ride.
  void resetForNewRide() {
    clearPause();
    _suggestEnd = false;
    _stillSince = null;
    _stillAnchorLat = null;
    _stillAnchorLng = null;
    _lastLat = null;
    _lastLng = null;
    _lastTs = null;
  }

  /// Clear auto-pause without resetting suggest-end / arm state.
  void clearPause() {
    _isPaused = false;
    _slowSince = null;
    _fastSince = null;
    _pausedAt = null;
    _pauseAnchorLat = null;
    _pauseAnchorLng = null;
  }

  /// Reset arm-state tracking. Call before (re)arming for auto-start.
  void resetArm() {
    _fastSinceArm = null;
    _armLastLat = null;
    _armLastLng = null;
    _armCumulativeMeters = 0;
  }

  /// Feed a location sample while a ride is recording (or auto-paused).
  /// Updates [isPaused] and [suggestEnd] as a side effect.
  ///
  /// [accuracyMeters] gates resume-by-distance so GPS wander at a red light
  /// does not look like rolling off.
  ///
  /// Android often reports [speedMps] = 0 when Doppler is missing. Pause
  /// then uses implied speed (meters / dt) when the hop is larger than the
  /// accuracy circle — otherwise 0 is treated as stopped.
  void feedRideSample({
    required double? speedMps,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    double? accuracyMeters,
  }) {
    final speed = _effectiveSpeedMps(
      speedMps,
      latitude,
      longitude,
      timestamp,
      accuracyMeters,
    );
    _updatePause(speed, latitude, longitude, timestamp, accuracyMeters);
    _updateSuggestEnd(speed, latitude, longitude, timestamp);
    _lastLat = latitude;
    _lastLng = longitude;
    _lastTs = timestamp;
  }

  /// Below ~1 km/h Android's 0.0 usually means "no speed", not parked.
  static const _usableGpsSpeedMps = 0.3;

  /// Wander smaller than this is not a ride, even with a tight accuracy.
  static const _impliedMinJumpMeters = 5.0;

  double _effectiveSpeedMps(
    double? speedMps,
    double lat,
    double lng,
    DateTime ts,
    double? accuracyMeters,
  ) {
    final implied = _credibleImpliedMps(lat, lng, ts, accuracyMeters);
    final gpsUsable =
        speedMps != null && speedMps > _usableGpsSpeedMps;
    if (gpsUsable && implied != null) {
      return math.max(speedMps, implied);
    }
    if (gpsUsable) return speedMps;
    if (implied != null) return implied;
    return speedMps ?? -1;
  }

  /// Implied m/s from the previous sample, or 0 when the hop is inside the
  /// error circle. Null on the first sample.
  double? _credibleImpliedMps(
    double lat,
    double lng,
    DateTime ts,
    double? accuracyMeters,
  ) {
    final prevLat = _lastLat;
    final prevLng = _lastLng;
    final prevTs = _lastTs;
    if (prevLat == null || prevLng == null || prevTs == null) return null;
    final dtSec = ts.difference(prevTs).inMilliseconds / 1000.0;
    if (dtSec < 0.05) return null;
    final jump = haversineMeters(prevLat, prevLng, lat, lng);
    final floor = math.max(accuracyMeters ?? 0, _impliedMinJumpMeters);
    if (jump <= floor) return 0;
    return jump / dtSec;
  }

  void _updatePause(
    double speed,
    double lat,
    double lng,
    DateTime ts,
    double? accuracyMeters,
  ) {
    if (!autoPauseEnabled) {
      if (_isPaused) clearPause();
      return;
    }
    if (!_isPaused) {
      if (speed >= 0 && speed < pauseSpeedThresholdMps) {
        _slowSince ??= ts;
        if (ts.difference(_slowSince!) >= pauseAfter) {
          _isPaused = true;
          _pausedAt = ts;
          _pauseAnchorLat = lat;
          _pauseAnchorLng = lng;
          _fastSince = null;
        }
      } else {
        _slowSince = null;
      }
      return;
    }

    // Paused: watch for sustained speed OR meaningful displacement.
    final anchorLat = _pauseAnchorLat;
    final anchorLng = _pauseAnchorLng;
    final movedMeters = anchorLat != null && anchorLng != null
        ? haversineMeters(anchorLat, anchorLng, lat, lng)
        : 0.0;

    if (speed >= 0 && speed > resumeSpeedThresholdMps) {
      _fastSince ??= ts;
    } else {
      _fastSince = null;
    }

    final sustainedFast =
        _fastSince != null && ts.difference(_fastSince!) >= resumeAfter;
    // Wander inside the fix's error circle is not "walking the bike out".
    final movedEnough = movedMeters > resumeDistanceMeters &&
        (accuracyMeters == null || movedMeters > accuracyMeters);

    if (sustainedFast || movedEnough) {
      _isPaused = false;
      _pausedAt = null;
      _pauseAnchorLat = null;
      _pauseAnchorLng = null;
      _slowSince = null;
      _fastSince = null;
    }
  }

  void _updateSuggestEnd(
    double? speedMps,
    double lat,
    double lng,
    DateTime ts,
  ) {
    final speed = speedMps ?? -1;
    final isSlow = speed < 0 || speed < suggestEndSpeedThresholdMps;

    if (!isSlow) {
      _stillSince = null;
      _stillAnchorLat = null;
      _stillAnchorLng = null;
      _suggestEnd = false;
      return;
    }

    final anchorLat = _stillAnchorLat;
    final anchorLng = _stillAnchorLng;
    if (_stillSince == null || anchorLat == null || anchorLng == null) {
      _stillSince = ts;
      _stillAnchorLat = lat;
      _stillAnchorLng = lng;
      return;
    }

    final moved = haversineMeters(anchorLat, anchorLng, lat, lng);
    if (moved > suggestEndDistanceMeters) {
      // Drifted (e.g. slow parking-lot maneuvering) — restart the window.
      _stillSince = ts;
      _stillAnchorLat = lat;
      _stillAnchorLng = lng;
      _suggestEnd = false;
      return;
    }

    if (ts.difference(_stillSince!) >= suggestEndAfter) {
      _suggestEnd = true;
    }
  }

  /// Feed a sample while armed (not yet recording). Returns true once the
  /// motion pattern indicates the ride has begun (caller should start()).
  bool feedArmedSample({
    required double? speedMps,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    if (_armLastLat != null && _armLastLng != null) {
      _armCumulativeMeters += haversineMeters(
        _armLastLat!,
        _armLastLng!,
        latitude,
        longitude,
      );
    }
    _armLastLat = latitude;
    _armLastLng = longitude;

    final speed = speedMps ?? -1;
    if (speed >= 0 && speed > autoStartSpeedThresholdMps) {
      _fastSinceArm ??= timestamp;
    } else {
      _fastSinceArm = null;
    }

    final sustained = _fastSinceArm != null &&
        timestamp.difference(_fastSinceArm!) >= autoStartAfter;
    final movedEnough = _armCumulativeMeters > autoStartDistanceMeters;

    return sustained || movedEnough;
  }
}
