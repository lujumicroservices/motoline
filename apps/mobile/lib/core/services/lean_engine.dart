import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../lean_lab/lean_imu_math.dart';
import 'location_service.dart';

/// Live snapshot of the mount-aware lean engine (same fields the IMU lab shows).
class LeanEngineSnapshot {
  const LeanEngineSnapshot({
    required this.at,
    required this.accel,
    required this.gravity,
    required this.linear,
    required this.gyroRad,
    required this.roll,
    required this.pitch,
    required this.tilt,
    required this.appLean,
    required this.fusedRoll,
    required this.fusedPitch,
    required this.vectorLean,
    required this.bikeLean,
    required this.upAxis,
    required this.pose,
    required this.winningChannel,
    required this.trackerConfidence,
    required this.frozen,
    required this.freezeUpAxis,
  });

  final DateTime at;
  final Vec3 accel;
  final Vec3 gravity;
  final Vec3 linear;
  final Vec3 gyroRad;
  final double roll;
  final double pitch;
  final double tilt;
  final double appLean;
  final double fusedRoll;
  final double fusedPitch;
  final double vectorLean;
  final double? bikeLean;
  final String upAxis;
  final PhonePoseClass pose;
  final String winningChannel;
  final double trackerConfidence;
  final bool frozen;
  final String? freezeUpAxis;
}

/// Pose-aware lean: freeze g0, classify mount, output signed bike lean.
///
/// `bikeLean = sign(winning fused Euler) × angle(g, g0)`
class LeanEngine extends ChangeNotifier {
  LeanEngine();

  final ComplementaryAttitude _attitude = ComplementaryAttitude();
  final ChannelTracker _tracker = ChannelTracker();
  final ListQueue<Vec3> _calibGravity = ListQueue<Vec3>();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _trackerTimer;

  Vec3 _accel = const Vec3(0, 0, 9.8);
  Vec3 _gyro = const Vec3(0, 0, 0);
  Vec3 _gravityLp = const Vec3(0, 9.8, 0);
  Vec3? _g0;
  DateTime? _lastGyroAt;
  DateTime? _startedAt;
  DateTime? _lastHeadingAt;
  double? _lastHeading;
  double _headingRateAbs = 0;
  double? _speedKmh;

  PhonePoseClass _pose = PhonePoseClass.unknown;
  String? _freezeUpAxis;
  double _freezeRoll = 0;
  double _freezePitch = 0;
  int _signFlip = 1;
  bool _locked = false;
  bool _calibrated = false;
  int _disagreeWindows = 0;
  double _trackerConfidence = 0;

  LeanEngineSnapshot? latest;
  bool running = false;

  bool get hasFreeze => _g0 != null;
  bool get isCalibrated => _calibrated;
  bool get isLocked => _locked;
  PhonePoseClass get pose => _pose;
  Vec3? get frozenGravity => _g0;
  int get signFlip => _signFlip;

  /// Signed bike lean (0 = upright at freeze). Null until g0 exists.
  double? get bikeLeanDegrees => latest?.bikeLean;

  /// Same as [bikeLeanDegrees] once frozen — stored on GPS points.
  double? get leanDegrees => bikeLeanDegrees;

  double? get vectorLeanDegrees => latest?.vectorLean;

  /// Legacy debug channel (closest-axis atan2). Not production lean.
  double? get appLeanDegrees => latest?.appLean;

  bool get isStill {
    final g = latest;
    if (g == null) return false;
    return g.gyroRad.mag * 180 / math.pi < 18 && g.linear.mag < 2.2;
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    _resetRuntime(keepLock: false);
    _startedAt = DateTime.now();

    const period = SensorInterval.gameInterval;
    _accelSub = accelerometerEventStream(samplingPeriod: period).listen((e) {
      _accel = Vec3(e.x, e.y, e.z);
      _gravityLp = Vec3(
        _gravityLp.x * 0.9 + e.x * 0.1,
        _gravityLp.y * 0.9 + e.y * 0.1,
        _gravityLp.z * 0.9 + e.z * 0.1,
      );
      if (!_locked && !_calibrated) {
        _calibGravity.addLast(_gravityLp);
        while (_calibGravity.length > 160) {
          _calibGravity.removeFirst();
        }
        _maybeAutoFreeze();
      }
      // If gyro is missing/late, still publish lean from gravity.
      final gyroAt = _lastGyroAt;
      if (gyroAt == null ||
          DateTime.now().difference(gyroAt) > const Duration(milliseconds: 80)) {
        final linear = _accel - _gravityLp;
        _attitude.update(
          accel: _gravityLp,
          gyroRad: _gyro,
          dtSec: 0.02,
          pose: _pose,
          linearMag: linear.mag,
        );
        _emit(DateTime.now());
      }
    }, onError: (_) {});

    _gyroSub = gyroscopeEventStream(samplingPeriod: period).listen((e) {
      final now = DateTime.now();
      final prev = _lastGyroAt;
      _lastGyroAt = now;
      _gyro = Vec3(e.x, e.y, e.z);
      final dt = prev == null
          ? 0.02
          : now.difference(prev).inMicroseconds / 1e6;
      final linear = _accel - _gravityLp;
      _attitude.update(
        accel: _gravityLp,
        gyroRad: _gyro,
        dtSec: dt,
        pose: _pose,
        linearMag: linear.mag,
      );
      _emit(now);
    }, onError: (_) {});

    _trackerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickTracker();
    });
  }

  void stop() {
    running = false;
    _trackerTimer?.cancel();
    _trackerTimer = null;
    unawaited(_accelSub?.cancel());
    unawaited(_gyroSub?.cancel());
    _accelSub = null;
    _gyroSub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Freeze current (or provided) gravity as upright. Stops auto-refine if
  /// [lock] is true (Lean Lab guided hold).
  void freezeUpright({
    Vec3? g0,
    int signFlip = 1,
    bool lock = true,
  }) {
    final captured = g0 ??
        (_calibGravity.length >= 8
            ? medianVec3(_calibGravity.toList(growable: false))
            : _gravityLp);
    _applyFreeze(captured, signFlip: signFlip, lock: lock);
  }

  void lockUpright(Vec3 g0, {int signFlip = 1}) {
    freezeUpright(g0: g0, signFlip: signFlip, lock: true);
  }

  void clearFreeze() {
    _g0 = null;
    _pose = PhonePoseClass.unknown;
    _freezeUpAxis = null;
    _freezeRoll = 0;
    _freezePitch = 0;
    _locked = false;
    _calibrated = false;
    _disagreeWindows = 0;
    _trackerConfidence = 0;
    _tracker.reset();
    _attitude.reset();
    _calibGravity.clear();
    notifyListeners();
  }

  void sampleForManualCalib() {
    _calibGravity.addLast(_gravityLp);
    while (_calibGravity.length > 160) {
      _calibGravity.removeFirst();
    }
  }

  Vec3? peekCalibGravity({int minSamples = 20}) {
    if (_calibGravity.length < minSamples) return null;
    return medianVec3(_calibGravity.toList(growable: false));
  }

  void clearCalibBuffer() {
    _calibGravity.clear();
  }

  /// While nearly stopped, keep refining g0 until locked (pocket settles).
  void observeForNeutral({required double? speedKmh}) {
    _speedKmh = speedKmh;
    if (_locked) return;
    if (speedKmh != null && speedKmh > 8) return;
    if (_calibrated && _calibGravity.length > 80) return;
    _calibGravity.addLast(_gravityLp);
    while (_calibGravity.length > 160) {
      _calibGravity.removeFirst();
    }
    if (_calibGravity.length >= 40) {
      _applyFreeze(
        medianVec3(_calibGravity.toList(growable: false)),
        signFlip: _signFlip,
        lock: false,
      );
    }
  }

  void observeGps({double? headingDeg, double? speedKmh}) {
    _speedKmh = speedKmh;
    if (headingDeg == null) return;
    final now = DateTime.now();
    final prevAt = _lastHeadingAt;
    final prev = _lastHeading;
    _lastHeadingAt = now;
    _lastHeading = headingDeg;
    if (prev == null || prevAt == null) return;
    final dt = now.difference(prevAt).inMilliseconds / 1000.0;
    if (dt < 0.05) return;
    var d = headingDeg - prev;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    _headingRateAbs = d.abs() / dt;
  }

  void _resetRuntime({required bool keepLock}) {
    if (!keepLock) {
      _g0 = null;
      _pose = PhonePoseClass.unknown;
      _freezeUpAxis = null;
      _locked = false;
      _calibrated = false;
      _signFlip = 1;
    }
    _attitude.reset();
    _tracker.reset();
    _calibGravity.clear();
    _disagreeWindows = 0;
    _trackerConfidence = 0;
    _headingRateAbs = 0;
    _lastHeading = null;
    _lastHeadingAt = null;
    _lastGyroAt = null;
    latest = null;
  }

  void _maybeAutoFreeze() {
    if (_locked || _calibrated) return;
    final started = _startedAt;
    if (started == null) return;
    final elapsed = DateTime.now().difference(started);
    if (elapsed >= const Duration(seconds: 3) && _calibGravity.length >= 40) {
      _applyFreeze(
        medianVec3(_calibGravity.toList(growable: false)),
        signFlip: _signFlip,
        lock: false,
      );
    }
  }

  void _applyFreeze(Vec3 g0, {required int signFlip, required bool lock}) {
    _g0 = g0;
    _signFlip = signFlip;
    _pose = poseFromGravity(g0);
    _freezeUpAxis = dominantUpAxis(g0);
    _freezeRoll = _attitude.seeded ? _attitude.roll : rollDeg(g0);
    _freezePitch = _attitude.seeded ? _attitude.pitch : pitchDeg(g0);
    _calibrated = true;
    _locked = lock;
    _disagreeWindows = 0;
    _emit(DateTime.now());
  }

  void _tickTracker() {
    if (_g0 == null || _pose == PhonePoseClass.unknown) return;
    final r = _tracker.evaluate(locked: _pose);
    _trackerConfidence = r.confidence;
    final live = poseFromGravity(_gravityLp);
    final winner = r.pose;
    if (winner == null || winner == _pose) {
      _disagreeWindows = 0;
      return;
    }
    final axisChanged = live != _pose && live != PhonePoseClass.unknown;
    final allowFlip = r.inCurve || axisChanged;
    if (!allowFlip) {
      _disagreeWindows = 0;
      return;
    }
    _disagreeWindows++;
    if (_disagreeWindows >= 3) {
      _pose = winner == PhonePoseClass.verticalY ? live : winner;
      if (_pose == PhonePoseClass.unknown) _pose = winner;
      _disagreeWindows = 0;
    }
  }

  void _emit(DateTime now) {
    final g = _gravityLp;
    final lin = _accel - g;
    final ref = _g0 ?? Vec3(0, g.mag, 0);
    final vector = gravityAngleDeg(g, ref);
    final fusedRoll = _attitude.roll;
    final fusedPitch = _attitude.pitch;
    _tracker.add(
      ChannelTrackerSample(
        fusedRollAbs: (fusedRoll - _freezeRoll).abs(),
        fusedPitchAbs: (fusedPitch - _freezePitch).abs(),
        pitchAbs: (pitchDeg(g) - _freezePitch).abs(),
        vector: vector,
        headingRateAbs: (_speedKmh != null && _speedKmh! > 20)
            ? _headingRateAbs
            : 0,
      ),
    );

    double? bike;
    if (_g0 != null && _pose != PhonePoseClass.unknown) {
      bike = signedBikeLean(
        gravity: g,
        g0: _g0!,
        pose: _pose,
        fusedRoll: fusedRoll,
        fusedPitch: fusedPitch,
        freezeRoll: _freezeRoll,
        freezePitch: _freezePitch,
        signFlip: _signFlip,
      );
    }

    latest = LeanEngineSnapshot(
      at: now,
      accel: _accel,
      gravity: g,
      linear: lin,
      gyroRad: _gyro,
      roll: rollDeg(g),
      pitch: pitchDeg(g),
      tilt: tiltFromVerticalDeg(g),
      appLean: leanFromAccelerometer(x: g.x, y: g.y, z: g.z),
      fusedRoll: fusedRoll,
      fusedPitch: fusedPitch,
      vectorLean: vector,
      bikeLean: bike,
      upAxis: dominantUpAxis(g),
      pose: _pose,
      winningChannel: _pose.winningChannel,
      trackerConfidence: _trackerConfidence,
      frozen: _g0 != null,
      freezeUpAxis: _freezeUpAxis,
    );
    if (hasListeners) notifyListeners();
  }
}
