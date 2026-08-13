import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/location_service.dart';
import 'lean_imu_math.dart';

class ImuSample {
  const ImuSample({
    required this.at,
    required this.accel,
    required this.gravity,
    required this.linear,
    required this.gyroRad,
    required this.mag,
    required this.pressureHpa,
    required this.roll,
    required this.pitch,
    required this.tilt,
    required this.appLean,
    required this.fusedRoll,
    required this.fusedPitch,
    required this.vectorLean,
    required this.heading,
    required this.upAxis,
    required this.accelHz,
    required this.gyroHz,
    required this.magHz,
    required this.baroHz,
  });

  final DateTime at;
  final Vec3 accel;
  final Vec3 gravity;
  final Vec3 linear;
  final Vec3 gyroRad;
  final Vec3? mag;
  final double? pressureHpa;
  final double roll;
  final double pitch;
  final double tilt;
  final double appLean;
  final double fusedRoll;
  final double fusedPitch;
  final double vectorLean;
  final double? heading;
  final String upAxis;
  final double accelHz;
  final double gyroHz;
  final double magHz;
  final double baroHz;

  double get gyroDegMag =>
      math.sqrt(
        gyroRad.x * gyroRad.x +
            gyroRad.y * gyroRad.y +
            gyroRad.z * gyroRad.z,
      ) *
      180 /
      math.pi;
}

/// Live multi-sensor capture for studying lean (accel + gyro + mag + baro).
class LeanImuLabSampler extends ChangeNotifier {
  LeanImuLabSampler();

  final _attitude = ComplementaryAttitude();
  final ListQueue<ImuSample> history = ListQueue<ImuSample>();

  static const _historyCap = 240; // ~8s at 30 Hz UI

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<BarometerEvent>? _baroSub;
  Timer? _tick;

  Vec3 _accel = const Vec3(0, 0, 9.8);
  Vec3 _gyro = const Vec3(0, 0, 0);
  Vec3? _mag;
  Vec3 _gravityLp = const Vec3(0, 9.8, 0);
  double? _pressure;
  Vec3? _frozenGravity;

  int _accelN = 0;
  int _gyroN = 0;
  int _magN = 0;
  int _baroN = 0;
  DateTime _hzAt = DateTime.now();
  double accelHz = 0;
  double gyroHz = 0;
  double magHz = 0;
  double baroHz = 0;

  DateTime? _lastGyroAt;
  ImuSample? latest;
  ImuSample? frozen;
  bool running = false;

  bool get hasFreeze => _frozenGravity != null;

  Future<void> start() async {
    if (running) return;
    running = true;
    _hzAt = DateTime.now();
    _attitude.reset();

    const period = SensorInterval.gameInterval;
    _accelSub = accelerometerEventStream(samplingPeriod: period).listen((e) {
      _accel = Vec3(e.x, e.y, e.z);
      _accelN++;
      _gravityLp = Vec3(
        _gravityLp.x * 0.9 + e.x * 0.1,
        _gravityLp.y * 0.9 + e.y * 0.1,
        _gravityLp.z * 0.9 + e.z * 0.1,
      );
    }, onError: (_) {});

    _gyroSub = gyroscopeEventStream(samplingPeriod: period).listen((e) {
      final now = DateTime.now();
      final prev = _lastGyroAt;
      _lastGyroAt = now;
      _gyro = Vec3(e.x, e.y, e.z);
      _gyroN++;
      final dt = prev == null
          ? 0.02
          : now.difference(prev).inMicroseconds / 1e6;
      _attitude.update(accel: _gravityLp, gyroRad: _gyro, dtSec: dt);
    }, onError: (_) {});

    _magSub = magnetometerEventStream(samplingPeriod: period).listen((e) {
      _mag = Vec3(e.x, e.y, e.z);
      _magN++;
    }, onError: (_) {});

    _baroSub = barometerEventStream(samplingPeriod: period).listen((e) {
      _pressure = e.pressure;
      _baroN++;
    }, onError: (_) {});

    _tick = Timer.periodic(const Duration(milliseconds: 33), (_) => _emit());
  }

  void freezeReference() {
    _frozenGravity = _gravityLp;
    frozen = latest;
    notifyListeners();
  }

  void clearFreeze() {
    _frozenGravity = null;
    frozen = null;
    _attitude.reset();
    notifyListeners();
  }

  void stop() {
    running = false;
    _tick?.cancel();
    _tick = null;
    unawaited(_accelSub?.cancel());
    unawaited(_gyroSub?.cancel());
    unawaited(_magSub?.cancel());
    unawaited(_baroSub?.cancel());
    _accelSub = null;
    _gyroSub = null;
    _magSub = null;
    _baroSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void _refreshHz(DateTime now) {
    final s = now.difference(_hzAt).inMilliseconds / 1000.0;
    if (s < 0.4) return;
    accelHz = _accelN / s;
    gyroHz = _gyroN / s;
    magHz = _magN / s;
    baroHz = _baroN / s;
    _accelN = 0;
    _gyroN = 0;
    _magN = 0;
    _baroN = 0;
    _hzAt = now;
  }

  void _emit() {
    final now = DateTime.now();
    _refreshHz(now);
    final g = _gravityLp;
    final lin = _accel - g;
    final ref = _frozenGravity ?? Vec3(0, g.mag, 0);
    final sample = ImuSample(
      at: now,
      accel: _accel,
      gravity: g,
      linear: lin,
      gyroRad: _gyro,
      mag: _mag,
      pressureHpa: _pressure,
      roll: rollDeg(g),
      pitch: pitchDeg(g),
      tilt: tiltFromVerticalDeg(g),
      appLean: leanFromAccelerometer(x: g.x, y: g.y, z: g.z),
      fusedRoll: _attitude.roll,
      fusedPitch: _attitude.pitch,
      vectorLean: gravityAngleDeg(g, ref),
      heading: _mag == null ? null : tiltCompensatedHeadingDeg(_mag!, g),
      upAxis: dominantUpAxis(g),
      accelHz: accelHz,
      gyroHz: gyroHz,
      magHz: magHz,
      baroHz: baroHz,
    );
    latest = sample;
    history.addLast(sample);
    while (history.length > _historyCap) {
      history.removeFirst();
    }
    notifyListeners();
  }
}
