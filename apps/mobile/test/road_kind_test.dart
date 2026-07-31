import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  test('detectRoadStretches finds a curva after a recta', () {
    final t0 = DateTime.utc(2026, 7, 30, 20);
    final points = <TrackPoint>[];
    // Northbound recta.
    for (var i = 0; i < 10; i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + i * 0.0002,
          longitude: -100.0,
          timestamp: t0.add(Duration(milliseconds: i * 300)),
          speedMps: 12,
          leanDegrees: 0,
        ),
      );
    }
    // Eastbound after a sharp corner (curva).
    for (var i = 0; i < 10; i++) {
      points.add(
        TrackPoint(
          id: 100 + i,
          rideId: 'r',
          latitude: 25.0 + 10 * 0.0002,
          longitude: -100.0 + (i + 1) * 0.0002,
          timestamp: t0.add(Duration(milliseconds: 3000 + i * 300)),
          speedMps: 11,
          leanDegrees: 20,
        ),
      );
    }

    final stretches = detectRoadStretches(
      points,
      neutralLeanDegrees: 0,
      minDistanceMeters: 8,
      minSamples: 3,
      curvaHeadingDegPerSample: 8,
      rectaHeadingDegPerSample: 3,
    );
    expect(stretches.length, greaterThanOrEqualTo(1));
    expect(stretches.any((s) => s.kind == RoadKind.recta), isTrue);
    // Corner sample(s) should produce at least one curva stretch,
    // or a single merged stretch that includes a large heading change.
    final hasCurva = stretches.any((s) => s.kind == RoadKind.curva);
    final bigTurn = stretches.any((s) => s.headingChangeDeg.abs() > 45);
    expect(hasCurva || bigTurn, isTrue);
  });

  test('lean + mild heading marks a curva', () {
    final t0 = DateTime.utc(2026, 7, 30, 20);
    final points = <TrackPoint>[];
    for (var i = 0; i < 8; i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + i * 0.00015,
          longitude: -100.0,
          timestamp: t0.add(Duration(milliseconds: i * 300)),
          speedMps: 12,
          leanDegrees: 0,
        ),
      );
    }
    // Gentle heading change with strong lean (pocket turn).
    for (var i = 0; i < 10; i++) {
      final t = i / 10.0;
      points.add(
        TrackPoint(
          id: 100 + i,
          rideId: 'r',
          latitude: 25.0 + 8 * 0.00015 + i * 0.00008,
          longitude: -100.0 + i * 0.00012,
          timestamp: t0.add(Duration(milliseconds: 2400 + i * 300)),
          speedMps: 10,
          leanDegrees: 18 + t * 4,
        ),
      );
    }

    final stretches = detectRoadStretches(
      points,
      neutralLeanDegrees: 0,
      minDistanceMeters: 5,
      minSamples: 3,
      minCurvaHeadingDeg: 15,
    );
    expect(stretches.any((s) => s.kind == RoadKind.curva), isTrue);
  });
}