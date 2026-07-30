import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/utils/geo_utils.dart';

void main() {
  test('haversine distance is roughly correct for short hop', () {
    // ~111 meters north at equator-ish
    final meters = haversineMeters(0, 0, 0.001, 0);
    expect(meters, greaterThan(100));
    expect(meters, lessThan(120));
  });

  test('splitByGpsGaps breaks on long pauses', () {
    final base = DateTime(2026, 1, 1);
    final points = [
      TrackPoint(
        id: 1,
        rideId: 'r',
        latitude: 1,
        longitude: 1,
        timestamp: base,
      ),
      TrackPoint(
        id: 2,
        rideId: 'r',
        latitude: 1.001,
        longitude: 1,
        timestamp: base.add(const Duration(seconds: 2)),
      ),
      TrackPoint(
        id: 3,
        rideId: 'r',
        latitude: 1.002,
        longitude: 1,
        timestamp: base.add(const Duration(seconds: 30)),
      ),
    ];
    final segments = splitByGpsGaps(points);
    expect(segments.length, 2);
    expect(segments.first.length, 2);
    expect(segments.last.length, 1);
  });

  test('pathDistanceMeters sums consecutive hops', () {
    final points = [
      TrackPoint(
        id: 1,
        rideId: 'r',
        latitude: 0,
        longitude: 0,
        timestamp: DateTime(2026),
      ),
      TrackPoint(
        id: 2,
        rideId: 'r',
        latitude: 0.001,
        longitude: 0,
        timestamp: DateTime(2026).add(const Duration(seconds: 1)),
      ),
    ];
    expect(pathDistanceMeters(points), greaterThan(100));
  });
}
