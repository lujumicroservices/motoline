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

  test('displaySpeedsMps fills Android GPS speed 0 from a real hop', () {
    final base = DateTime.utc(2026, 9, 8);
    // ~11.1 m north per 0.0001 deg. 20 m in 1 s ≈ 72 km/h.
    final points = [
      TrackPoint(
        id: 1,
        rideId: 'r',
        latitude: 0,
        longitude: 0,
        timestamp: base,
        speedMps: 0,
        accuracyMeters: 8,
      ),
      TrackPoint(
        id: 2,
        rideId: 'r',
        latitude: 0.0002,
        longitude: 0,
        timestamp: base.add(const Duration(seconds: 1)),
        speedMps: 0,
        accuracyMeters: 8,
      ),
    ];
    final speeds = displaySpeedsMps(points);
    expect(speeds[1], isNotNull);
    expect(speeds[1]! * 3.6, greaterThan(50));
    expect(speeds[1]! * 3.6, lessThan(90));
    expect(speeds[0], speeds[1]);
  });

  test('displaySpeedsMps keeps GPS Doppler when it is real', () {
    final base = DateTime.utc(2026, 9, 8);
    final points = [
      TrackPoint(
        id: 1,
        rideId: 'r',
        latitude: 0,
        longitude: 0,
        timestamp: base,
        speedMps: 20,
      ),
      TrackPoint(
        id: 2,
        rideId: 'r',
        latitude: 0.00002,
        longitude: 0,
        timestamp: base.add(const Duration(seconds: 1)),
        speedMps: 20,
        accuracyMeters: 8,
      ),
    ];
    final speeds = displaySpeedsMps(points);
    expect(speeds[1], 20);
  });

  test('displaySpeedsMps does not invent speed from GPS wander', () {
    final base = DateTime.utc(2026, 9, 8);
    final points = [
      TrackPoint(
        id: 1,
        rideId: 'r',
        latitude: 0,
        longitude: 0,
        timestamp: base,
        speedMps: 0,
        accuracyMeters: 15,
      ),
      TrackPoint(
        id: 2,
        rideId: 'r',
        latitude: 0.00001,
        longitude: 0,
        timestamp: base.add(const Duration(seconds: 1)),
        speedMps: 0,
        accuracyMeters: 15,
      ),
    ];
    final speeds = displaySpeedsMps(points);
    expect(speeds[1], 0);
  });
}
