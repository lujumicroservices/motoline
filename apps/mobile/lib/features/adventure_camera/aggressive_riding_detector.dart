/// Aggressive riding = speed ≥ [minSpeedKmh] **and** ongoing lean changes.
///
/// Starts when both conditions are true; pauses when lean changes stop
/// (left the curve series) or speed drops below the threshold.
enum AggressiveRidingAction { start, pause }

class AggressiveRidingDetector {
  AggressiveRidingDetector({
    this.minSpeedKmh = 85,
    this.leanChangeDegrees = 8,
    this.leanFlipDegrees = 16,
    this.changesToStart = 3,
    this.changeWindow = const Duration(seconds: 6),
    this.exitQuiet = const Duration(seconds: 8),
    this.startCooldown = const Duration(seconds: 20),
  });

  /// Aggressive only above this speed.
  final double minSpeedKmh;

  /// Minimum |Δlean| between samples to count as a lean change.
  final double leanChangeDegrees;

  /// Left↔right swing that always counts as a lean change.
  final double leanFlipDegrees;

  /// Lean changes required inside [changeWindow] (at speed) to start.
  final int changesToStart;

  final Duration changeWindow;

  /// No lean changes for this long → pause (left curve series).
  final Duration exitQuiet;

  /// Debounce after a start/pause cycle.
  final Duration startCooldown;

  bool _inCurves = false;
  DateTime? _lastActivityAt;
  DateTime? _lastStartAt;
  DateTime? _belowSpeedSince;
  double? _prevLean;
  final List<DateTime> _changeAts = [];

  bool get inCurves => _inCurves;

  void reset() {
    _inCurves = false;
    _lastActivityAt = null;
    _lastStartAt = null;
    _belowSpeedSince = null;
    _prevLean = null;
    _changeAts.clear();
  }

  /// Call on every live sample while aggressive mode is enabled.
  AggressiveRidingAction? feed({
    required DateTime timestamp,
    double? leanDegrees,
    double? speedKmh,
  }) {
    final speed = speedKmh;
    final lean = leanDegrees;
    final fastEnough = speed != null && speed >= minSpeedKmh;

    _pruneChanges(timestamp);
    final changed = _noteLeanChange(lean, timestamp, count: fastEnough);

    if (_inCurves) {
      return _feedWhileInCurves(
        timestamp: timestamp,
        fastEnough: fastEnough,
        leanChanged: changed,
      );
    }

    return _feedWhileIdle(
      timestamp: timestamp,
      fastEnough: fastEnough,
    );
  }

  AggressiveRidingAction? _feedWhileIdle({
    required DateTime timestamp,
    required bool fastEnough,
  }) {
    if (!fastEnough) return null;

    if (_lastStartAt != null &&
        timestamp.difference(_lastStartAt!) < startCooldown) {
      return null;
    }

    // Formula: speed ≥ 85 AND constant lean changes.
    if (_changeAts.length < changesToStart) return null;

    _enterCurves(timestamp);
    return AggressiveRidingAction.start;
  }

  AggressiveRidingAction? _feedWhileInCurves({
    required DateTime timestamp,
    required bool fastEnough,
    required bool leanChanged,
  }) {
    if (leanChanged) {
      _touchActivity(timestamp);
    }

    if (!fastEnough) {
      _belowSpeedSince ??= timestamp;
    } else {
      _belowSpeedSince = null;
    }

    final quiet = _lastActivityAt == null ||
        timestamp.difference(_lastActivityAt!) >= exitQuiet;
    final tooSlow = _belowSpeedSince != null &&
        timestamp.difference(_belowSpeedSince!) >= exitQuiet;

    if (quiet || tooSlow) {
      _leaveCurves();
      return AggressiveRidingAction.pause;
    }
    return null;
  }

  void _enterCurves(DateTime timestamp) {
    _inCurves = true;
    _lastStartAt = timestamp;
    _touchActivity(timestamp);
    _belowSpeedSince = null;
    _changeAts.clear();
  }

  void _leaveCurves() {
    _inCurves = false;
    _lastActivityAt = null;
    _belowSpeedSince = null;
    _changeAts.clear();
  }

  void _touchActivity(DateTime timestamp) {
    _lastActivityAt = timestamp;
  }

  /// Returns true when this sample is a meaningful lean change.
  bool _noteLeanChange(double? lean, DateTime timestamp, {required bool count}) {
    if (lean == null) return false;
    final prev = _prevLean;
    _prevLean = lean;
    if (prev == null) return false;

    final delta = (lean - prev).abs();
    final flipped =
        (prev <= -leanFlipDegrees && lean >= leanFlipDegrees) ||
        (prev >= leanFlipDegrees && lean <= -leanFlipDegrees);
    final changed = flipped || delta >= leanChangeDegrees;
    if (!changed) return false;

    if (count) {
      _changeAts.add(timestamp);
      _touchActivity(timestamp);
    }
    return true;
  }

  void _pruneChanges(DateTime timestamp) {
    _changeAts.removeWhere(
      (t) => timestamp.difference(t) > changeWindow,
    );
  }
}
