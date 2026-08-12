import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/location_service.dart';

void main() {
  test('maxPlausibleJumpMeters allows moto speed over a few seconds', () {
    // 80 km/h for 5s ≈ 111 m — old hard 80 m filter would drop this.
    final maxJump = maxPlausibleJumpMeters(
      dtSeconds: 5,
      accuracyMeters: 5,
      previousAccuracyMeters: 5,
    );
    expect(maxJump, greaterThan(111));
    expect(111 < maxJump, isTrue);
  });

  test('maxPlausibleJumpMeters still rejects teleports', () {
    final maxJump = maxPlausibleJumpMeters(
      dtSeconds: 1,
      accuracyMeters: 5,
      previousAccuracyMeters: 5,
    );
    expect(500 > maxJump, isTrue);
  });

  test('leanFromAccelerometer is near zero when upright on Y', () {
    final lean = leanFromAccelerometer(x: 0, y: 9.8, z: 0);
    expect(lean.abs(), lessThan(1));
  });

  test('leanFromAccelerometer grows when phone rolls on X', () {
    // ~30° roll from portrait upright.
    const deg = 30.0;
    final rad = deg * math.pi / 180;
    final lean = leanFromAccelerometer(
      x: -9.8 * math.sin(rad),
      y: 9.8 * math.cos(rad),
      z: 0,
    );
    expect(lean.abs(), closeTo(deg, 2));
  });

  test('leanFromAccelerometer measures wall tip (pitch), not only roll', () {
    // Portrait phone tipped ~27° toward/away from wall (clinometer case).
    // Old roll-only formula returned ~0 because x≈0.
    const deg = 27.0;
    final rad = deg * math.pi / 180;
    final lean = leanFromAccelerometer(
      x: 0,
      y: 9.8 * math.cos(rad),
      z: 9.8 * math.sin(rad),
    );
    expect(lean.abs(), closeTo(deg, 2));
  });
}
