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

  test('pose class follows dominant gravity axis', () {
    expect(poseFromGravity(const Vec3(0, 9.8, 0)), PhonePoseClass.verticalY);
    expect(poseFromGravity(const Vec3(0, -9.8, 0)), PhonePoseClass.verticalY);
    expect(poseFromGravity(const Vec3(9.8, 0, 0)), PhonePoseClass.landscapeX);
    expect(poseFromGravity(const Vec3(0, 0, 9.8)), PhonePoseClass.flatZ);
  });

  test('vertical wall tip uses fused roll sign and vector magnitude', () {
    const g0 = Vec3(0, 9.8, 0);
    const deg = 30.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    final lean = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: rollDeg(g),
      fusedPitch: pitchDeg(g),
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(lean.abs(), closeTo(deg, 1.5));
    expect(lean, greaterThan(0));
  });

  test('flat 27° tip uses vector magnitude, not portrait roll', () {
    const g0 = Vec3(0, 0, 9.8);
    const deg = 27.0;
    final rad = deg * math.pi / 180;
    // Screen-up phone, gravity rotates toward +Y (roll stays quiet).
    final g = Vec3(0, 9.8 * math.sin(rad), 9.8 * math.cos(rad));
    expect(rollDeg(g).abs(), lessThan(2));
    final lean = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.flatZ,
      fusedRoll: rollDeg(g),
      fusedPitch: pitchDeg(g),
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(lean.abs(), closeTo(deg, 2));
  });

  test('screen-in flips bike-lean sign', () {
    const g0 = Vec3(0, 9.8, 0);
    const deg = 20.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    final out = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: rollDeg(g),
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
    );
    final inward = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: rollDeg(g),
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
      signFlip: -1,
    );
    expect(inward, closeTo(-out, 0.01));
  });

  test('tracker picks fused roll when it follows vector, ignores a straight', () {
    final tracker = ChannelTracker(windowSize: 80);
    for (var i = 0; i < 40; i++) {
      tracker.add(const ChannelTrackerSample(
        fusedRollAbs: 1,
        fusedPitchAbs: 0.4,
        pitchAbs: 0.3,
        vector: 1,
        headingRateAbs: 0,
      ));
    }
    final quiet = tracker.evaluate(locked: PhonePoseClass.verticalY);
    expect(quiet.pose, isNull);

    for (var i = 0; i < 50; i++) {
      final t = i / 50;
      final lean = 8 + 20 * math.sin(t * math.pi);
      tracker.add(ChannelTrackerSample(
        fusedRollAbs: lean,
        fusedPitchAbs: 2 + t,
        pitchAbs: 1.5,
        vector: lean,
        headingRateAbs: 12,
      ));
    }
    final turning = tracker.evaluate(locked: PhonePoseClass.verticalY);
    expect(turning.pose, PhonePoseClass.verticalY);
    expect(turning.confidence, greaterThan(0.55));
  });

  test('tracker does not flip pose on a straight with hill pitch', () {
    final tracker = ChannelTracker(windowSize: 80);
    for (var i = 0; i < 60; i++) {
      tracker.add(ChannelTrackerSample(
        fusedRollAbs: 1.2,
        fusedPitchAbs: 6 + i * 0.02,
        pitchAbs: 6 + i * 0.02,
        vector: 6 + i * 0.02,
        headingRateAbs: 0.4,
      ));
    }
    final r = tracker.evaluate(locked: PhonePoseClass.verticalY);
    // Pitch may correlate, but engine keeps last pose unless in a curve.
    expect(r.inCurve, isFalse);
  });
}
