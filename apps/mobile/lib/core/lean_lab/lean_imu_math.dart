import 'dart:math' as math;

/// Phone-frame IMU helpers for the Lean IMU Lab (study, not production lean).
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
    // gyro.x ≈ pitch rate, gyro.y ≈ roll rate in phone frame (portrait).
    roll = alpha * (roll + _deg(gyroRad.y) * dt) + (1 - alpha) * aRoll;
    pitch = alpha * (pitch + _deg(gyroRad.x) * dt) + (1 - alpha) * aPitch;
  }
}
