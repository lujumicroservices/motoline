import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/ride_analytics.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  test('segment metrics use only the selected window', () {
    final start = DateTime.utc(2026, 7, 30, 12);
    final points = [
      for (var i = 0; i < 10; i++)
        TrackPoint(
          id: i,
          rideId: 'r1',
          latitude: 25.0 + i * 0.0001,
          longitude: -100.0,
          timestamp: start.add(Duration(seconds: i)),
          speedMps: i < 5 ? 5 : 20,
          accuracyMeters: 5,
        ),
    ];
    final ride = Ride(
      id: 'r1',
      startedAt: start,
      status: RideStatus.completed,
      endedAt: start.add(const Duration(seconds: 9)),
      pointCount: points.length,
    );
    final full = RideAnalytics(ride: ride, points: points);
    final seg = full.segment(5, 9);

    expect(seg.samples.length, 5);
    expect(seg.isSegment, isTrue);
    expect(seg.maxSpeedKmh, closeTo(72, 0.1)); // 20 m/s
    expect(full.maxSpeedKmh, closeTo(72, 0.1));
    expect(seg.distanceKm, lessThan(full.distanceKm));
    expect(seg.mapIndexOffset, 5);
  });
}
