import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/curva_analysis.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  test('CurvaAnalysis finds entry apex exit speeds', () {
    final t0 = DateTime.utc(2026, 7, 30, 21);
    final points = <TrackPoint>[
      for (var i = 0; i < 12; i++)
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + i * 0.00005,
          longitude: -100.0 + (i > 5 ? (i - 5) * 0.00005 : 0),
          timestamp: t0.add(Duration(milliseconds: i * 200)),
          // Enter 18, slow to ~8 at mid, exit 15
          speedMps: i < 3
              ? 5.0
              : i < 7
                  ? 5.0 - (i - 2) * 0.6
                  : 2.2 + (i - 7) * 0.5,
          leanDegrees: i >= 4 && i <= 8 ? 22.0 : 2.0,
        ),
    ];

    final stretch = RoadStretch(
      startIndex: 0,
      endIndex: 11,
      kind: RoadKind.curva,
      side: TurnSide.derecha,
      distanceMeters: 40,
      duration: const Duration(seconds: 2),
      headingChangeDeg: 70,
      avgAbsLeanDeg: 15,
    );

    final analysis = CurvaAnalysis.fromRide(
      samples: points,
      stretch: stretch,
      neutralLeanDegrees: 0,
    );

    expect(analysis, isNotNull);
    expect(analysis!.entrySpeedKmh, greaterThan(analysis.apexSpeedKmh));
    expect(analysis.exitSpeedKmh, greaterThan(analysis.apexSpeedKmh - 1));
    expect(analysis.apexIndex, inInclusiveRange(2, 10));
  });
}
