import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/curva_analysis.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/lean_sample.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  TrackPoint gps({
    required int i,
    required double lean,
    required double heading,
    double speed = 15,
  }) {
    return TrackPoint(
      id: null,
      rideId: 'r',
      latitude: 20.6 + i * 0.0001,
      longitude: -103.4 + i * 0.00005,
      speedMps: speed,
      heading: heading,
      leanDegrees: lean,
      timestamp: DateTime(2026, 1, 1, 12, 0, i),
    );
  }

  test('lean apex prefers 10 Hz peak over GPS score apex', () {
    final samples = <TrackPoint>[
      for (var i = 0; i < 20; i++)
        gps(
          i: i,
          lean: i == 10 ? 20 : 8,
          heading: i * 4.0,
          speed: i == 12 ? 8 : 18,
        ),
    ];
    // High-rate peak at second 7 (between GPS i=7).
    final leanSeries = <LeanSample>[
      for (var ms = 0; ms <= 19000; ms += 100)
        LeanSample(
          rideId: 'r',
          timestampMs: DateTime(2026, 1, 1, 12)
              .add(Duration(milliseconds: ms))
              .millisecondsSinceEpoch,
          leanDegrees: ms == 7000 ? 42 : 10,
        ),
    ];
    final stretch = RoadStretch(
      kind: RoadKind.curva,
      side: TurnSide.derecha,
      startIndex: 2,
      endIndex: 18,
      headingChangeDeg: 60,
      distanceMeters: 80,
      duration: const Duration(seconds: 16),
      avgAbsLeanDeg: 15,
    );
    final a = CurvaAnalysis.fromRide(
      samples: samples,
      stretch: stretch,
      neutralLeanDegrees: 0,
      leanSamples: leanSeries,
    )!;
    expect(a.leanApexDegrees!.abs(), closeTo(42, 0.1));
    expect(a.leanApexLat, isNotNull);
    expect(a.geoApexIndex, isNotNull);
    expect(a.displayApexIndex, a.leanApexIndex);
  });

  test('interpolateLatLngAtMs blends between GPS fixes', () {
    final samples = [
      gps(i: 0, lean: 0, heading: 0),
      gps(i: 1, lean: 0, heading: 10),
    ];
    final t0 = samples.first.timestamp.millisecondsSinceEpoch;
    final t1 = samples.last.timestamp.millisecondsSinceEpoch;
    final mid = interpolateLatLngAtMs(samples, (t0 + t1) ~/ 2)!;
    expect(mid.$1, closeTo(20.6 + 0.00005, 1e-6));
  });
}
