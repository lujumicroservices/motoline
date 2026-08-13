import 'dart:collection';
import 'dart:math' as math;

/// Phone-frame IMU helpers shared by the IMU lab and production LeanEngine.
///
/// Android / sensors_plus convention (portrait):
/// X right, Y up the screen, Z out of the screen. Gravity ≈ +Y when upright.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get mag => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final m = mag;
    if (m < 1e-9) return const Vec3(0, 0, 0);
    return Vec3(x / m, y / m, z / m);
  }

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  @override
  String toString() =>
      '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

double _deg(double rad) => rad * 180 / math.pi;

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

/// Roll around the phone long axis (left/right when portrait). Degrees.
/// Matches the old production formula: `atan2(-x, √(y²+z²))`.
double rollDeg(Vec3 a) {
  final den = math.sqrt(a.y * a.y + a.z * a.z);
  if (den < 1e-6 && a.x.abs() < 1e-6) return 0;
  return _deg(math.atan2(-a.x, den));
}

/// Pitch / fore-aft tip (toward/away, wall-lean). Degrees.
/// `atan2(z, y)` is ~0 when Y is up, grows when gravity rotates into Z.
double pitchDeg(Vec3 a) {
  final den = math.sqrt(a.x * a.x + a.y * a.y);
  if (den < 1e-6 && a.z.abs() < 1e-6) return 0;
  return _deg(math.atan2(a.z, a.y));
}

/// Unsigned tilt from vertical (clinometer magnitude). 0 = upright along
/// whichever phone axis is closest to world-up.
double tiltFromVerticalDeg(Vec3 a) {
  final g = a.mag;
  if (g < 1e-6) return 0;
  final nx = (a.x / g).abs();
  final ny = (a.y / g).abs();
  final nz = (a.z / g).abs();
  final up = math.max(nx, math.max(ny, nz));
  return _deg(math.acos(_clamp(up, 0, 1)));
}

/// Angle between two gravity vectors (degrees). This is mount-independent
/// "how far did we rotate from the frozen upright".
double gravityAngleDeg(Vec3 a, Vec3 b) {
  final na = a.normalized;
  final nb = b.normalized;
  if (na.mag < 1e-6 || nb.mag < 1e-6) return 0;
  return _deg(math.acos(_clamp(na.dot(nb), -1, 1)));
}

/// Which phone axis currently points closest to world-up (gravity).
String dominantUpAxis(Vec3 a) {
  final ax = a.x.abs();
  final ay = a.y.abs();
  final az = a.z.abs();
  if (ay >= ax && ay >= az) return a.y >= 0 ? '+Y' : '−Y';
  if (ax >= ay && ax >= az) return a.x >= 0 ? '+X' : '−X';
  return a.z >= 0 ? '+Z' : '−Z';
}

/// Tilt-compensated compass heading (0–360°, magnetic). Null if mag weak.
double? tiltCompensatedHeadingDeg(Vec3 mag, Vec3 gravity) {
  if (mag.mag < 8) return null;
  final g = gravity.normalized;
  // East = mag × gravity, North = gravity × east
  final east = mag.cross(g);
  if (east.mag < 1e-6) return null;
  final e = east.normalized;
  final north = g.cross(e);
  var h = _deg(math.atan2(e.x, north.x));
  if (h < 0) h += 360;
  return h;
}

/// How the phone sits in the mount. Sensors pick this from g0 — not the
/// rider's mount/pose chips (those are training labels).
enum PhonePoseClass {
  unknown,
  verticalY,
  landscapeX,
  flatZ;

  String get id => switch (this) {
        PhonePoseClass.unknown => 'unknown',
        PhonePoseClass.verticalY => 'vertical_y',
        PhonePoseClass.landscapeX => 'landscape_x',
        PhonePoseClass.flatZ => 'flat_z',
      };

  String get label => switch (this) {
        PhonePoseClass.unknown => 'Unknown',
        PhonePoseClass.verticalY => 'Vertical',
        PhonePoseClass.landscapeX => 'Landscape',
        PhonePoseClass.flatZ => 'Flat',
      };

  /// Euler used for left/right sign (magnitude always comes from vector).
  String get winningChannel => switch (this) {
        PhonePoseClass.unknown => 'none',
        PhonePoseClass.verticalY => 'fusedRoll',
        PhonePoseClass.landscapeX => 'fusedPitch',
        PhonePoseClass.flatZ => 'flatSign',
      };
}

PhonePoseClass poseFromUpAxis(String axis) {
  if (axis == '+Y' || axis == '−Y' || axis == '-Y') {
    return PhonePoseClass.verticalY;
  }
  if (axis == '+X' || axis == '−X' || axis == '-X') {
    return PhonePoseClass.landscapeX;
  }
  if (axis == '+Z' || axis == '−Z' || axis == '-Z') {
    return PhonePoseClass.flatZ;
  }
  return PhonePoseClass.unknown;
}

PhonePoseClass poseFromGravity(Vec3 g) => poseFromUpAxis(dominantUpAxis(g));

/// Portrait-like roll/pitch rates from phone-frame gyro, remapped by pose.
({double rollRate, double pitchRate}) gyroRatesForPose(
  Vec3 gyroRad,
  PhonePoseClass pose,
) {
  return switch (pose) {
    PhonePoseClass.verticalY || PhonePoseClass.unknown => (
        rollRate: gyroRad.y,
        pitchRate: gyroRad.x,
      ),
    PhonePoseClass.landscapeX => (
        rollRate: gyroRad.z,
        pitchRate: gyroRad.y,
      ),
    PhonePoseClass.flatZ => (
        rollRate: gyroRad.z,
        pitchRate: gyroRad.x,
      ),
  };
}

/// Left/right sign when the phone is flat (screen up/down). Matches roll
/// convention: negative X is positive lean.
double flatLeanSign(Vec3 gravity, Vec3 g0) {
  final g = gravity.normalized;
  final r = g0.normalized;
  final dx = g.x - r.x;
  final dy = g.y - r.y;
  if (dx.abs() >= dy.abs()) {
    return dx == 0 ? 1.0 : -dx.sign;
  }
  return dy == 0 ? 1.0 : dy.sign;
}

double eulerSign(double degrees) => degrees == 0 ? 1.0 : degrees.sign;

/// Production lean: vector magnitude (clinometer) × sign from the winning
/// fused Euler (or flat-plane gravity for screen-up mounts).
double signedBikeLean({
  required Vec3 gravity,
  required Vec3 g0,
  required PhonePoseClass pose,
  required double fusedRoll,
  required double fusedPitch,
  required double freezeRoll,
  required double freezePitch,
  int signFlip = 1,
}) {
  if (pose == PhonePoseClass.unknown) return 0;
  final mag = gravityAngleDeg(gravity, g0);
  final double signed;
  switch (pose) {
    case PhonePoseClass.verticalY:
      signed = eulerSign(fusedRoll - freezeRoll) * mag;
    case PhonePoseClass.landscapeX:
      signed = eulerSign(fusedPitch - freezePitch) * mag;
    case PhonePoseClass.flatZ:
      signed = flatLeanSign(gravity, g0) * mag;
    case PhonePoseClass.unknown:
      signed = 0;
  }
  return (signed * signFlip).clamp(-70.0, 70.0);
}

Vec3 medianVec3(List<Vec3> samples) {
  if (samples.isEmpty) return const Vec3(0, 0, 0);
  final xs = samples.map((v) => v.x).toList()..sort();
  final ys = samples.map((v) => v.y).toList()..sort();
  final zs = samples.map((v) => v.z).toList()..sort();
  return Vec3(_medianSorted(xs), _medianSorted(ys), _medianSorted(zs));
}

double _medianSorted(List<double> sorted) {
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

double? pearsonCorr(List<double> x, List<double> y) {
  if (x.length != y.length || x.length < 8) return null;
  final n = x.length;
  var sx = 0.0, sy = 0.0;
  for (var i = 0; i < n; i++) {
    sx += x[i];
    sy += y[i];
  }
  final mx = sx / n;
  final my = sy / n;
  var num = 0.0, dx = 0.0, dy = 0.0;
  for (var i = 0; i < n; i++) {
    final a = x[i] - mx;
    final b = y[i] - my;
    num += a * b;
    dx += a * a;
    dy += b * b;
  }
  final den = math.sqrt(dx * dy);
  if (den < 1e-9) return null;
  return _clamp(num / den, -1, 1);
}

double sampleVariance(List<double> x) {
  if (x.length < 2) return 0;
  var sum = 0.0;
  for (final v in x) {
    sum += v;
  }
  final mean = sum / x.length;
  var acc = 0.0;
  for (final v in x) {
    final d = v - mean;
    acc += d * d;
  }
  return acc / (x.length - 1);
}

class ChannelTrackerSample {
  const ChannelTrackerSample({
    required this.fusedRollAbs,
    required this.fusedPitchAbs,
    required this.pitchAbs,
    required this.vector,
    required this.headingRateAbs,
  });

  final double fusedRollAbs;
  final double fusedPitchAbs;
  final double pitchAbs;
  final double vector;
  final double headingRateAbs;
}

class ChannelTrackerResult {
  const ChannelTrackerResult({
    required this.pose,
    required this.confidence,
    required this.inCurve,
    this.corrRoll,
    this.corrPitch,
  });

  final PhonePoseClass? pose;
  final double confidence;
  final bool inCurve;
  final double? corrRoll;
  final double? corrPitch;
}

/// ~4–6 s window: which |Euler| follows vector lean?
/// Returns null pose when the road is straight / energy is noise — keep last.
class ChannelTracker {
  ChannelTracker({this.windowSize = 120});

  final int windowSize;
  final ListQueue<ChannelTrackerSample> _buf = ListQueue<ChannelTrackerSample>();

  static const minCorr = 0.55;
  static const minEnergy = 4.0;

  void add(ChannelTrackerSample s) {
    _buf.addLast(s);
    while (_buf.length > windowSize) {
      _buf.removeFirst();
    }
  }

  void reset() => _buf.clear();

  ChannelTrackerResult evaluate({required PhonePoseClass locked}) {
    final n = _buf.length;
    if (n < 24) {
      return ChannelTrackerResult(pose: null, confidence: 0, inCurve: false);
    }
    final roll = [for (final s in _buf) s.fusedRollAbs];
    final pitch = [for (final s in _buf) s.fusedPitchAbs];
    final pitchRaw = [for (final s in _buf) s.pitchAbs];
    final vec = [for (final s in _buf) s.vector];
    var headingSum = 0.0;
    for (final s in _buf) {
      headingSum += s.headingRateAbs;
    }
    final inCurve = headingSum / n > 4;

    final corrRoll = pearsonCorr(roll, vec);
    final corrPitchFused = pearsonCorr(pitch, vec);
    final corrPitchRaw = pearsonCorr(pitchRaw, vec);
    final corrPitch = () {
      final a = corrPitchFused?.abs() ?? 0;
      final b = corrPitchRaw?.abs() ?? 0;
      if (b > a) return corrPitchRaw;
      return corrPitchFused;
    }();

    final eRoll = sampleVariance(roll);
    final ePitch = math.max(sampleVariance(pitch), sampleVariance(pitchRaw));
    final scoreRoll = (corrRoll?.abs() ?? 0) * eRoll;
    final scorePitch = (corrPitch?.abs() ?? 0) * ePitch;

    final rollOk = (corrRoll?.abs() ?? 0) > minCorr && eRoll > minEnergy;
    final pitchOk = (corrPitch?.abs() ?? 0) > minCorr && ePitch > minEnergy;

    PhonePoseClass? winner;
    var conf = 0.0;
    if (rollOk && (!pitchOk || scoreRoll >= scorePitch)) {
      winner = PhonePoseClass.verticalY;
      conf = corrRoll!.abs();
    } else if (pitchOk) {
      winner = locked == PhonePoseClass.flatZ
          ? PhonePoseClass.flatZ
          : PhonePoseClass.landscapeX;
      conf = corrPitch!.abs();
    }

    return ChannelTrackerResult(
      pose: winner,
      confidence: conf,
      inCurve: inCurve,
      corrRoll: corrRoll,
      corrPitch: corrPitch,
    );
  }
}

class ComplementaryAttitude {
  ComplementaryAttitude({this.alpha = 0.98});

  /// 1 = trust gyro more. ~0.96–0.98 typical at 50 Hz.
  final double alpha;
  double roll = 0;
  double pitch = 0;
  bool seeded = false;

  void reset() {
    roll = 0;
    pitch = 0;
    seeded = false;
  }

  void update({
    required Vec3 accel,
    required Vec3 gyroRad,
    required double dtSec,
    PhonePoseClass pose = PhonePoseClass.unknown,
    double linearMag = 0,
  }) {
    final aRoll = rollDeg(accel);
    final aPitch = pitchDeg(accel);
    if (!seeded) {
      roll = aRoll;
      pitch = aPitch;
      seeded = true;
      return;
    }
    final dt = dtSec.clamp(0.001, 0.1);
    var a = alpha;
    if (linearMag < 1.5) {
      a = 0.92;
    } else if (linearMag > 4) {
      a = 0.99;
    }
    final rates = gyroRatesForPose(gyroRad, pose);
    roll = a * (roll + _deg(rates.rollRate) * dt) + (1 - a) * aRoll;
    pitch = a * (pitch + _deg(rates.pitchRate) * dt) + (1 - a) * aPitch;
  }
}
