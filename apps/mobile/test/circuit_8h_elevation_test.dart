import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/experimental/circuit_8h/circuit_8h_elevation.dart';
import 'package:motoline/features/experimental/circuit_8h/circuit_8h_models.dart';

void main() {
  test('elevation climb/descent ignores sub-threshold noise', () {
    final stats = circuit8hElevationStats([
      const Circuit8hPoint(lat: 0, lng: 0, tsMs: 1, altM: 100),
      const Circuit8hPoint(lat: 0, lng: 0, tsMs: 2, altM: 100.2),
      const Circuit8hPoint(lat: 0, lng: 0, tsMs: 3, altM: 105),
      const Circuit8hPoint(lat: 0, lng: 0, tsMs: 4, altM: 102),
    ]);
    expect(stats.hasAltitude, isTrue);
    expect(stats.minAltM, 100);
    expect(stats.maxAltM, 105);
    expect(stats.climbM, closeTo(4.8, 0.01));
    expect(stats.descentM, closeTo(3.0, 0.01));
  });

  test('point json round-trips altitude fields', () {
    const p = Circuit8hPoint(
      lat: 20.6,
      lng: -103.4,
      tsMs: 1,
      accuracyM: 3,
      altM: 1580.5,
      altAccuracyM: 8,
    );
    final back = Circuit8hPoint.fromJson(p.toJson());
    expect(back.altM, 1580.5);
    expect(back.altAccuracyM, 8);
  });
}
