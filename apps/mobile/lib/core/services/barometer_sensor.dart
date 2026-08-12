import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Live atmospheric pressure from the phone barometer (hPa).
class BarometerSensor {
  StreamSubscription<BarometerEvent>? _sub;
  double? _pressureHpa;
  bool _available = true;

  double? get pressureHpa => _pressureHpa;
  bool get isAvailable => _available && _pressureHpa != null;

  void start() {
    stop();
    _available = true;
    try {
      _sub = barometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen(
        (e) {
          final p = e.pressure;
          if (p.isNaN || p <= 0 || p > 1200) return;
          _pressureHpa = p;
        },
        onError: (Object e, StackTrace st) {
          debugPrint('Barometer unavailable: $e');
          _available = false;
          _pressureHpa = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Barometer start failed: $e');
      _available = false;
    }
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
