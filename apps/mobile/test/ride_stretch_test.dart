import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/ride_stretch.dart';
import 'package:motoline/core/models/track_point.dart';

TrackPoint _pt(int id, DateTime t, {double lat = 0, double lng = 0}) {
  return TrackPoint(
    id: id,
    rideId: 'r',
    latitude: lat,
    longitude: lng,
    timestamp: t,
  );
}

void main() {
  group('rideStretchesFrom', () {
    test('continuous rolling is one stretch', () {
      final base = DateTime(2026, 8, 20, 12);
      final points = [
        for (var i = 0; i < 10; i++)
          _pt(i, base.add(Duration(seconds: i)), lat: i * 0.0002),
      ];
      expect(rideStretchesFrom(points), hasLength(1));
    });

    test('stop-like gap splits a new tramo', () {
      final base = DateTime(2026, 8, 20, 12);
      final points = [
        _pt(1, base),
        _pt(2, base.add(const Duration(seconds: 2)), lat: 0.001),
        _pt(3, base.add(const Duration(seconds: 40)), lat: 0.001),
        _pt(4, base.add(const Duration(seconds: 42)), lat: 0.002),
      ];
      final stretches = rideStretchesFrom(points);
      expect(stretches, hasLength(2));
      expect(stretches.first.duration, const Duration(seconds: 2));
      expect(stretches.first.distanceMeters, greaterThan(100));
    });

    test('moving GPS hole (tunnel) stays one tramo', () {
      final base = DateTime(2026, 8, 20, 12);
      // ~333 m in 15 s ≈ 22 m/s — rolling, not a stop.
      final points = [
        _pt(1, base),
        _pt(2, base.add(const Duration(seconds: 2)), lat: 0.001),
        _pt(3, base.add(const Duration(seconds: 17)), lat: 0.004),
        _pt(4, base.add(const Duration(seconds: 19)), lat: 0.005),
      ];
      expect(rideStretchesFrom(points), hasLength(1));
    });

    test('lone GPS blip after a stop is absorbed', () {
      final base = DateTime(2026, 8, 20, 12);
      final points = [
        _pt(1, base),
        _pt(2, base.add(const Duration(seconds: 2)), lat: 0.001),
        _pt(3, base.add(const Duration(seconds: 40)), lat: 0.0011),
        _pt(4, base.add(const Duration(seconds: 80)), lat: 0.0011),
        _pt(5, base.add(const Duration(seconds: 82)), lat: 0.002),
      ];
      final stretches = rideStretchesFrom(points);
      expect(stretches, hasLength(2));
      expect(stretches.first.pointCount, 3);
      expect(stretches.last.pointCount, 2);
    });
  });
}
