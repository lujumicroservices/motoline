import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import 'location_service.dart';

/// Samples accelerometer and exposes a low-pass filtered lean angle.
class LeanSensor {
  StreamSubscription<AccelerometerEvent>? _sub;
  double? _leanDegrees;
  DateTime? _updatedAt;

  double? get leanDegrees => _leanDegrees;
  DateTime? get updatedAt => _updatedAt;

  void start() {
    _sub?.cancel();
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen((event) {
      final sample = leanFromAccelerometer(
        x: event.x,
        y: event.y,
        z: event.z,
      );
      final previous = _leanDegrees;
      // Light smoothing — keep corner lean responsive.
      _leanDegrees =
          previous == null ? sample : previous * 0.8 + sample * 0.2;
      _updatedAt = DateTime.now();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
