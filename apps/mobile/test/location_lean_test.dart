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

  test('leanFromAccelerometer is near zero when upright on Z', () {
    final lean = leanFromAccelerometer(x: 0, y: 0, z: 9.8);
    expect(lean.abs(), lessThan(1));
  });

  test('leanFromAccelerometer grows when phone rolls on X', () {
    final lean = leanFromAccelerometer(x: 5, y: 0, z: 8);
    expect(lean.abs(), greaterThan(20));
  });
}
