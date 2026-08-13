import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/lean_lab/lean_imu_math.dart';

void main() {
  test('portrait upright is ~0 roll/pitch/tilt', () {
    const g = Vec3(0, 9.8, 0);
    expect(rollDeg(g).abs(), lessThan(1));
    expect(pitchDeg(g).abs(), lessThan(1));
    expect(tiltFromVerticalDeg(g).abs(), lessThan(1));
    expect(dominantUpAxis(g), '+Y');
  });

  test('roll-only lean is ~30° and pitch stays small', () {
    const deg = 30.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    expect(rollDeg(g).abs(), closeTo(deg, 1.5));
    expect(pitchDeg(g).abs(), lessThan(2));
  });

  test('wall tip (pitch) is ~27° and roll stays small', () {
    const deg = 27.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(0, 9.8 * math.cos(rad), 9.8 * math.sin(rad));
    expect(pitchDeg(g).abs(), closeTo(deg, 1.5));
    expect(rollDeg(g).abs(), lessThan(2));
    expect(tiltFromVerticalDeg(g), closeTo(deg, 2));
  });

  test('vector lean matches 3D angle from freeze in any direction', () {
    const upright = Vec3(0, 9.8, 0);
    const deg = 40.0;
    final rad = deg * math.pi / 180;
    final wall = Vec3(0, 9.8 * math.cos(rad), 9.8 * math.sin(rad));
    final roll = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    expect(gravityAngleDeg(wall, upright), closeTo(deg, 1.5));
    expect(gravityAngleDeg(roll, upright), closeTo(deg, 1.5));
  });
}
