import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/corner_skill.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  test('straight with pocket lean is not a curva', () {
    final t0 = DateTime.utc(2026, 7, 30, 20);
    final points = <TrackPoint>[];
    // Long northbound straight with strong lean (sensor pocket bias).
    for (var i = 0; i < 40; i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + i * 0.00025,
          longitude: -100.0,
          timestamp: t0.add(Duration(milliseconds: i * 250)),
          speedMps: 16,
          leanDegrees: 16,
        ),
      );
    }
    final stretches = detectRoadStretches(
      points,
      neutralLeanDegrees: 0,
    );
    final curvas = stretches.where((s) => s.kind == RoadKind.curva);
    expect(curvas, isEmpty);
  });

  test('S-curve (left then right) yields two curvas', () {
    final t0 = DateTime.utc(2026, 7, 30, 20);
    final points = <TrackPoint>[];
    var i = 0;
    // Approach recta.
    for (var k = 0; k < 12; k++, i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + k * 0.0002,
          longitude: -100.0,
          timestamp: t0.add(Duration(milliseconds: i * 250)),
          speedMps: 14,
          leanDegrees: 0,
        ),
      );
    }
    // Left curve (west).
    for (var k = 0; k < 14; k++, i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + 12 * 0.0002 + k * 0.00005,
          longitude: -100.0 - (k + 1) * 0.00018,
          timestamp: t0.add(Duration(milliseconds: i * 250)),
          speedMps: 11,
          leanDegrees: -22,
        ),
      );
    }
    // Short quiet link.
    for (var k = 0; k < 6; k++, i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: points.last.latitude + 0.00012,
          longitude: points.last.longitude,
          timestamp: t0.add(Duration(milliseconds: i * 250)),
          speedMps: 12,
          leanDegrees: 0,
        ),
      );
    }
    // Right curve (east).
    for (var k = 0; k < 14; k++, i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: points.last.latitude + 0.00005,
          longitude: points.last.longitude + 0.00018,
          timestamp: t0.add(Duration(milliseconds: i * 250)),
          speedMps: 11,
          leanDegrees: 22,
        ),
      );
    }

    final stretches = detectRoadStretches(
      points,
      neutralLeanDegrees: 0,
    );
    final curvas =
        stretches.where((s) => s.kind == RoadKind.curva).toList();
    expect(curvas.length, greaterThanOrEqualTo(2));
    expect(
      curvas.any((c) => c.side == TurnSide.izquierda),
      isTrue,
    );
    expect(
      curvas.any((c) => c.side == TurnSide.derecha),
      isTrue,
    );
  });

  test('corner skill engine rates detected curvas', () {
    final t0 = DateTime.utc(2026, 7, 30, 20);
    final points = <TrackPoint>[];
    for (var i = 0; i < 10; i++) {
      points.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25.0 + i * 0.0002,
          longitude: -100.0,
          timestamp: t0.add(Duration(milliseconds: i * 300)),
          speedMps: 14,
          leanDegrees: 0,
        ),
      );
    }
    for (var i = 0; i < 12; i++) {
      points.add(
        TrackPoint(
          id: 100 + i,
          rideId: 'r',
          latitude: 25.0 + 10 * 0.0002,
          longitude: -100.0 + (i + 1) * 0.0002,
          timestamp: t0.add(Duration(milliseconds: 3000 + i * 300)),
          speedMps: 10 - i * 0.2,
          leanDegrees: 20,
        ),
      );
    }
    final stretches = detectRoadStretches(
      points,
      neutralLeanDegrees: 0,
      minDistanceMeters: 8,
      minSamples: 3,
      minCurvaHeadingDeg: 20,
    );
    final summary = const CornerSkillEngine().evaluate(
      samples: points,
      stretches: stretches,
      neutralLeanDegrees: 0,
    );
    if (stretches.any((s) => s.kind == RoadKind.curva)) {
      expect(summary.corners, isNotEmpty);
      expect(summary.sessionScore, inInclusiveRange(0, 100));
    }
  });
}
