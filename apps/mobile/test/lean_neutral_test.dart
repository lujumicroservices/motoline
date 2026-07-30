import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/lean_neutral.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  TrackPoint point({
    required double lean,
    double speedMps = 0,
    int seconds = 0,
  }) {
    return TrackPoint(
      id: null,
      rideId: 'r',
      latitude: 20.6,
      longitude: -103.4,
      speedMps: speedMps,
      leanDegrees: lean,
      timestamp: DateTime(2026, 1, 1).add(Duration(seconds: seconds)),
    );
  }

  test('infers pocket neutral from slow samples near a constant offset', () {
    final samples = <TrackPoint>[
      for (var i = 0; i < 20; i++)
        point(lean: 35 + (i.isEven ? 0.4 : -0.3), speedMps: 0.2, seconds: i),
      for (var i = 0; i < 10; i++)
        point(lean: 35 - 25, speedMps: 12, seconds: 30 + i), // left bank
      for (var i = 0; i < 10; i++)
        point(lean: 35 + 20, speedMps: 14, seconds: 50 + i), // right bank
    ];

    final neutral = inferNeutralLeanDegrees(samples);
    expect(neutral, closeTo(35, 1.5));

    final sides = leanSideStats(samples: samples, neutralDegrees: neutral);
    expect(sides.maxLeftDegrees, greaterThan(20));
    expect(sides.maxRightDegrees, greaterThan(15));
  });

  test('relativeLeanDegrees centers around zero', () {
    expect(
      relativeLeanDegrees(rawLeanDegrees: 40, neutralDegrees: 35),
      closeTo(5, 0.01),
    );
    expect(
      relativeLeanDegrees(rawLeanDegrees: 10, neutralDegrees: 35),
      closeTo(-25, 0.01),
    );
  });
}
