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

  test('vertical roll lean uses vector magnitude and fused-roll sign', () {
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

  test('pitch-only wall tip does not dump 3D magnitude onto roll sign', () {
    const g0 = Vec3(0, 9.8, 0);
    const deg = 27.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(0, 9.8 * math.cos(rad), 9.8 * math.sin(rad));
    final lean = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: 0.4, // chatter around freeze
      fusedPitch: pitchDeg(g),
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(gravityAngleDeg(g, g0), closeTo(deg, 2));
    expect(lean.abs(), lessThan(6));
  });

  test('fused chatter around 0 does not square-wave ±vector', () {
    const g0 = Vec3(0, 9.8, 0);
    const deg = 20.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    final a = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: 0.6,
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
    );
    final b = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: -0.5,
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(a.abs(), lessThan(8));
    expect(b.abs(), lessThan(8));
    expect(a * b, lessThan(0)); // signs follow fused, not ±20
  });

  test('large fused zero-cross follows continuous roll, not ±vector jump', () {
    const g0 = Vec3(0, 9.8, 0);
    const deg = 35.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
    final pos = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: 12,
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
    );
    final neg = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.verticalY,
      fusedRoll: -12,
      fusedPitch: 0,
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(pos, closeTo(12, 0.5));
    expect(neg, closeTo(-12, 0.5));
    // Old bug: would have been ≈ ±35 (sign × vector).
    expect(pos.abs(), lessThan(20));
    expect(neg.abs(), lessThan(20));
  });

  test('flat 27° tip uses vector magnitude and flat-plane sign', () {
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
      freezeRoll: rollDeg(g0),
      freezePitch: pitchDeg(g0),
    );
    expect(lean.abs(), closeTo(deg, 2));
  });

  test('landscape tip uses fused pitch sign and vector magnitude', () {
    const g0 = Vec3(9.8, 0, 0);
    const deg = 25.0;
    final rad = deg * math.pi / 180;
    final g = Vec3(9.8 * math.cos(rad), 9.8 * math.sin(rad), 0);
    expect(poseFromGravity(g0), PhonePoseClass.landscapeX);
    final lean = signedBikeLean(
      gravity: g,
      g0: g0,
      pose: PhonePoseClass.landscapeX,
      fusedRoll: 0,
      fusedPitch: deg,
      freezeRoll: 0,
      freezePitch: 0,
    );
    expect(gravityAngleDeg(g, g0), closeTo(deg, 2));
    expect(lean.abs(), closeTo(deg, 2));
    expect(lean, greaterThan(0));
  });

  test('flat pose uses gyro Y for bike lean, not yaw Z', () {
    const gyro = Vec3(0.1, 0.4, 0.9);
    final rates = gyroRatesForPose(gyro, PhonePoseClass.flatZ);
    expect(rates.rollRate, closeTo(0.4, 1e-9));
    expect(rates.pitchRate, closeTo(0.1, 1e-9));
  });

  test('vector magnitude stays within ~3° of true tip (clinometer check)', () {
    const upright = Vec3(0, 9.8, 0);
    for (final deg in [10.0, 27.0, 40.0]) {
      final rad = deg * math.pi / 180;
      final tip = Vec3(-9.8 * math.sin(rad), 9.8 * math.cos(rad), 0);
      expect(gravityAngleDeg(tip, upright), closeTo(deg, 3));
    }
    const flat0 = Vec3(0, 0, 9.8);
    final flatTip = Vec3(0, 9.8 * math.sin(27 * math.pi / 180),
        9.8 * math.cos(27 * math.pi / 180));
    expect(gravityAngleDeg(flatTip, flat0), closeTo(27, 3));
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

  test('gps kinematic lean grows with speed and yaw rate', () {
    expect(
      gpsKinematicLeanDegrees(speedMps: 5, headingRateDegPerSec: 20),
      isNull,
    );
    final mild = gpsKinematicLeanDegrees(
      speedMps: 20,
      headingRateDegPerSec: 15,
    )!;
    final hard = gpsKinematicLeanDegrees(
      speedMps: 30,
      headingRateDegPerSec: 25,
    )!;
    expect(mild, greaterThan(5));
    expect(hard.abs(), greaterThan(mild.abs()));
    expect(
      gpsKinematicLeanDegrees(speedMps: 20, headingRateDegPerSec: -15)!,
      closeTo(-mild, 0.2),
    );
  });

  test('lean confidence drops on IMU/GPS disagreement', () {
    final ok = leanConfidenceScore(
      frozen: true,
      pose: PhonePoseClass.verticalY,
      trackerConfidence: 0.8,
      uprightLocked: true,
      mountMode: 'mount',
      imuLeanDeg: 35,
      gpsLeanDeg: 32,
    );
    final bad = leanConfidenceScore(
      frozen: true,
      pose: PhonePoseClass.verticalY,
      trackerConfidence: 0.8,
      uprightLocked: true,
      mountMode: 'pocket',
      imuLeanDeg: 55,
      gpsLeanDeg: 25,
    );
    expect(ok, greaterThan(bad));
    expect(ok, greaterThan(0.5));
  });

  test('lean side asymmetry flags pocket bias', () {
    expect(
      leanSideAsymmetry(maxLeftDegrees: 30, maxRightDegrees: 29),
      lessThan(0.1),
    );
    expect(
      leanSideAsymmetry(maxLeftDegrees: 60, maxRightDegrees: 30),
      greaterThan(0.4),
    );
  });
}
