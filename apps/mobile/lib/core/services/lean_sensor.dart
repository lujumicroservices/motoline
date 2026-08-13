import '../lean_lab/lean_imu_math.dart';
import 'lean_engine.dart';

/// Production lean facade. Pose-aware [LeanEngine] underneath; same getters
/// the recorder, prep screen, and live gauge already use.
class LeanSensor {
  LeanSensor({LeanEngine? engine}) : _engine = engine ?? LeanEngine();

  final LeanEngine _engine;

  LeanEngine get engine => _engine;

  /// Signed bike lean once g0 is frozen; null before that.
  double? get rawLeanDegrees => _engine.leanDegrees;

  /// Same as [rawLeanDegrees] — output is already relative to freeze.
  double? get leanDegrees => _engine.leanDegrees;

  /// Always 0 after a vector freeze (lean is already bike-relative).
  double? get neutralDegrees => _engine.hasFreeze ? 0 : null;

  bool get isCalibrated => _engine.isCalibrated;
  bool get isLocked => _engine.isLocked;
  DateTime? get updatedAt => _engine.latest?.at;
  PhonePoseClass get pose => _engine.pose;
  LeanEngineSnapshot? get snapshot => _engine.latest;
  bool get isStill => _engine.isStill;
  Vec3? get frozenGravity => _engine.frozenGravity;

  void start() => _engine.start();

  void stop() => _engine.stop();

  /// Guided freeze: lock current / provided gravity as upright.
  void lockUpright(Vec3 g0, {int signFlip = 1}) {
    _engine.lockUpright(g0, signFlip: signFlip);
  }

  /// Legacy scalar lock. Freezes current gravity (lean is already 0 at g0).
  void lockNeutral(double degrees) {
    final _ = degrees;
    final g0 = _engine.frozenGravity ?? _engine.latest?.gravity;
    if (g0 != null) {
      _engine.freezeUpright(g0: g0, signFlip: _engine.signFlip, lock: true);
    } else {
      _engine.freezeUpright(lock: true);
    }
  }

  void sampleForManualCalib() => _engine.sampleForManualCalib();

  double? peekCalibNeutral({int minSamples = 25}) {
    final g = _engine.peekCalibGravity(minSamples: minSamples);
    if (g == null) return null;
    return 0;
  }

  Vec3? peekCalibGravity({int minSamples = 20}) =>
      _engine.peekCalibGravity(minSamples: minSamples);

  void clearCalibBuffer() => _engine.clearCalibBuffer();

  void observeForNeutral({required double? speedKmh}) {
    _engine.observeForNeutral(speedKmh: speedKmh);
  }

  void observeGps({double? headingDeg, double? speedKmh}) {
    _engine.observeGps(headingDeg: headingDeg, speedKmh: speedKmh);
  }
}
