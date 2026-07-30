import 'dart:async';
import 'dart:collection';

import 'package:sensors_plus/sensors_plus.dart';

import '../analytics/lean_neutral.dart';
import 'location_service.dart';

/// High-rate accelerometer lean with automatic neutral (pocket) calibration.
class LeanSensor {
  StreamSubscription<AccelerometerEvent>? _sub;
  double? _rawLeanDegrees;
  double? _neutralDegrees;
  DateTime? _updatedAt;
  DateTime? _calibStartedAt;
  final ListQueue<double> _calibBuffer = ListQueue<double>();
  bool _calibrated = false;

  /// Raw phone lean (mount/pocket absolute).
  double? get rawLeanDegrees => _rawLeanDegrees;

  /// Lean relative to inferred upright (0 = bike upright).
  double? get leanDegrees {
    final raw = _rawLeanDegrees;
    if (raw == null) return null;
    return relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: _neutralDegrees ?? 0,
    );
  }

  double? get neutralDegrees => _neutralDegrees;
  bool get isCalibrated => _calibrated;
  DateTime? get updatedAt => _updatedAt;

  void start() {
    _sub?.cancel();
    _rawLeanDegrees = null;
    _neutralDegrees = null;
    _calibrated = false;
    _calibBuffer.clear();
    _calibStartedAt = DateTime.now();

    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((event) {
      final sample = leanFromAccelerometer(
        x: event.x,
        y: event.y,
        z: event.z,
      );
      final previous = _rawLeanDegrees;
      _rawLeanDegrees =
          previous == null ? sample : previous * 0.7 + sample * 0.3;
      _updatedAt = DateTime.now();
      _maybeFinishCalibration(_rawLeanDegrees!);
    });
  }

  /// While nearly stopped, keep refining neutral (pocket settles).
  void observeForNeutral({required double? speedKmh}) {
    final raw = _rawLeanDegrees;
    if (raw == null) return;
    if (speedKmh != null && speedKmh > 8) return;
    if (_calibrated && _calibBuffer.length > 80) return;
    _calibBuffer.addLast(raw);
    while (_calibBuffer.length > 120) {
      _calibBuffer.removeFirst();
    }
    if (_calibBuffer.length >= 40) {
      _neutralDegrees = _median(_calibBuffer.toList(growable: false));
      _calibrated = true;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _maybeFinishCalibration(double raw) {
    if (_calibrated) return;
    final started = _calibStartedAt;
    if (started == null) return;
    _calibBuffer.addLast(raw);
    while (_calibBuffer.length > 120) {
      _calibBuffer.removeFirst();
    }
    final elapsed = DateTime.now().difference(started);
    if (elapsed >= const Duration(seconds: 3) && _calibBuffer.length >= 40) {
      _neutralDegrees = _median(_calibBuffer.toList(growable: false));
      _calibrated = true;
    }
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
