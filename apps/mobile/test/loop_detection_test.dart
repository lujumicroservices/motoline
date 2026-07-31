import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/services/loop_detection.dart';

void main() {
  test('detectClosedLoops finds return near start', () {
    final start = DateTime(2026, 1, 1, 12);
    final points = <TrackPoint>[];
    // Out and back square-ish path that returns to start.
    for (var i = 0; i < 40; i++) {
      points.add(
        TrackPoint(
          id: null,
          rideId: 'r1',
          latitude: 19.0 + (i < 20 ? i * 0.0003 : (40 - i) * 0.0003),
          longitude: -99.0,
          timestamp: start.add(Duration(seconds: i * 2)),
        ),
      );
    }
    // Force last points very close to first.
    points[points.length - 1] = TrackPoint(
      id: null,
      rideId: 'r1',
      latitude: 19.0,
      longitude: -99.0,
      timestamp: start.add(const Duration(seconds: 90)),
    );

    final found = detectClosedLoops(
      rideId: 'r1',
      points: points,
      closeRadiusM: 80,
      minPathMeters: 100,
      minDuration: const Duration(seconds: 20),
    );
    expect(found, isNotEmpty);
    expect(found.first.rideId, 'r1');
  });
}
