/// Detects aggressive motorcycle riding from live lean + speed samples.
///
/// Used to auto-start the adventure camera mid-ride when the rider starts
/// pushing hard (corner lean and/or strong acceleration).
class AggressiveRidingDetector {
  AggressiveRidingDetector({
    this.leanThresholdDegrees = 22,
    this.leanHold = const Duration(milliseconds: 1200),
    this.accelDeltaKmh = 18,
    this.accelWindow = const Duration(seconds: 2),
    this.cooldown = const Duration(seconds: 45),
    this.minSpeedKmh = 25,
  });

  final double leanThresholdDegrees;
  final Duration leanHold;
  final double accelDeltaKmh;
  final Duration accelWindow;
  final Duration cooldown;
  final double minSpeedKmh;

  DateTime? _leanSince;
  double? _prevSpeedKmh;
  DateTime? _prevSpeedAt;
  DateTime? _lastFiredAt;

  void reset() {
    _leanSince = null;
    _prevSpeedKmh = null;
    _prevSpeedAt = null;
    _lastFiredAt = null;
  }

  /// Returns true once when aggressive riding is detected (edge-triggered).
  bool feed({
    required DateTime timestamp,
    double? leanDegrees,
    double? speedKmh,
  }) {
    if (_lastFiredAt != null &&
        timestamp.difference(_lastFiredAt!) < cooldown) {
      _trackSpeed(speedKmh, timestamp);
      return false;
    }

    final speed = speedKmh;
    final moving = speed != null && speed >= minSpeedKmh;

    // Sustained lean while moving.
    final absLean = leanDegrees?.abs();
    if (moving && absLean != null && absLean >= leanThresholdDegrees) {
      _leanSince ??= timestamp;
      if (timestamp.difference(_leanSince!) >= leanHold) {
        _lastFiredAt = timestamp;
        _leanSince = null;
        _trackSpeed(speedKmh, timestamp);
        return true;
      }
    } else {
      _leanSince = null;
    }

    // Hard acceleration window.
    if (moving && _prevSpeedKmh != null && _prevSpeedAt != null) {
      final dt = timestamp.difference(_prevSpeedAt!);
      if (dt > Duration.zero && dt <= accelWindow) {
        final delta = speed - _prevSpeedKmh!;
        if (delta >= accelDeltaKmh) {
          _lastFiredAt = timestamp;
          _trackSpeed(speedKmh, timestamp);
          return true;
        }
      }
    }

    _trackSpeed(speedKmh, timestamp);
    return false;
  }

  void _trackSpeed(double? speedKmh, DateTime timestamp) {
    if (speedKmh == null) return;
    _prevSpeedKmh = speedKmh;
    _prevSpeedAt = timestamp;
  }
}
