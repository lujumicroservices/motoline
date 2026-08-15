import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/lean_engine.dart';
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
    required this.bikeLean,
    required this.gpsLean,
    required this.leanConfidence,
    required this.heading,
    required this.upAxis,
    required this.pose,
    required this.winningChannel,
    required this.trackerConfidence,
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
  final double? bikeLean;
  final double? gpsLean;
  final double leanConfidence;
  final double? heading;
  final String upAxis;
  final PhonePoseClass pose;
  final String winningChannel;
  final double trackerConfidence;
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

/// Live multi-sensor capture for studying lean. Accel/gyro/lean come from
/// the same [LeanEngine] production uses; mag/baro stay lab-only.
class LeanImuLabSampler extends ChangeNotifier {
  LeanImuLabSampler({LeanEngine? engine}) : engine = engine ?? LeanEngine();

  final LeanEngine engine;
  final ListQueue<ImuSample> history = ListQueue<ImuSample>();

  static const _historyCap = 240; // ~8s at 30 Hz UI

  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<BarometerEvent>? _baroSub;
  Timer? _tick;

  Vec3? _mag;
  double? _pressure;

  int _imuN = 0;
  int _magN = 0;
  int _baroN = 0;
  DateTime _hzAt = DateTime.now();
  double accelHz = 0;
  double gyroHz = 0;
  double magHz = 0;
  double baroHz = 0;

  ImuSample? latest;
  ImuSample? frozen;
  bool running = false;
  bool recording = false;

  /// Longer buffer while recording (~3 min @ 30 Hz) for CSV export.
  static const _recordCap = 5400;

  bool get hasFreeze => engine.hasFreeze;

  void startRecording() {
    recording = true;
    history.clear();
    notifyListeners();
  }

  void stopRecording() {
    recording = false;
    notifyListeners();
  }

  /// CSV of the ring buffer (or active recording). Columns match the chart.
  String exportCsv() {
    final buf = StringBuffer();
    buf.writeln(
      't_ms,bike_lean,vector,roll,pitch,fused_roll,fused_pitch,'
      'pose,channel,confidence,gx,gy,gz,ax,ay,az',
    );
    for (final s in history) {
      final g = s.gravity;
      final a = s.accel;
      buf.writeln(
        '${s.at.millisecondsSinceEpoch},'
        '${s.bikeLean?.toStringAsFixed(3) ?? ''},'
        '${s.vectorLean.toStringAsFixed(3)},'
        '${s.roll.toStringAsFixed(3)},'
        '${s.pitch.toStringAsFixed(3)},'
        '${s.fusedRoll.toStringAsFixed(3)},'
        '${s.fusedPitch.toStringAsFixed(3)},'
        '${s.pose.id},'
        '${s.winningChannel},'
        '${s.leanConfidence.toStringAsFixed(3)},'
        '${g.x.toStringAsFixed(4)},${g.y.toStringAsFixed(4)},${g.z.toStringAsFixed(4)},'
        '${a.x.toStringAsFixed(4)},${a.y.toStringAsFixed(4)},${a.z.toStringAsFixed(4)}',
      );
    }
    return buf.toString();
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    _hzAt = DateTime.now();
    engine.addListener(_onEngine);
    await engine.start();

    const period = SensorInterval.gameInterval;
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
    engine.freezeUpright(lock: true);
    frozen = latest;
    notifyListeners();
  }

  void clearFreeze() {
    engine.clearFreeze();
    frozen = null;
    notifyListeners();
  }

  void stop() {
    running = false;
    _tick?.cancel();
    _tick = null;
    engine.removeListener(_onEngine);
    engine.stop();
    unawaited(_magSub?.cancel());
    unawaited(_baroSub?.cancel());
    _magSub = null;
    _baroSub = null;
  }

  @override
  void dispose() {
    stop();
    engine.dispose();
    super.dispose();
  }

  void _onEngine() => _imuN++;

  void _refreshHz(DateTime now) {
    final s = now.difference(_hzAt).inMilliseconds / 1000.0;
    if (s < 0.4) return;
    accelHz = _imuN / s;
    gyroHz = _imuN / s;
    magHz = _magN / s;
    baroHz = _baroN / s;
    _imuN = 0;
    _magN = 0;
    _baroN = 0;
    _hzAt = now;
  }

  void _emit() {
    final snap = engine.latest;
    if (snap == null) return;
    final now = DateTime.now();
    _refreshHz(now);
    final sample = ImuSample(
      at: snap.at,
      accel: snap.accel,
      gravity: snap.gravity,
      linear: snap.linear,
      gyroRad: snap.gyroRad,
      mag: _mag,
      pressureHpa: _pressure,
      roll: snap.roll,
      pitch: snap.pitch,
      tilt: snap.tilt,
      appLean: snap.appLean,
      fusedRoll: snap.fusedRoll,
      fusedPitch: snap.fusedPitch,
      vectorLean: snap.vectorLean,
      bikeLean: snap.bikeLean,
      gpsLean: snap.gpsLean,
      leanConfidence: snap.leanConfidence,
      heading: _mag == null ? null : tiltCompensatedHeadingDeg(_mag!, snap.gravity),
      upAxis: snap.upAxis,
      pose: snap.pose,
      winningChannel: snap.winningChannel,
      trackerConfidence: snap.trackerConfidence,
      accelHz: accelHz,
      gyroHz: gyroHz,
      magHz: magHz,
      baroHz: baroHz,
    );
    latest = sample;
    history.addLast(sample);
    final cap = recording ? _recordCap : _historyCap;
    while (history.length > cap) {
      history.removeFirst();
    }
    notifyListeners();
  }
}
