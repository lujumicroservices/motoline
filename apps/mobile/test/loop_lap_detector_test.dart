import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/loop_lap_detector.dart';
import 'package:motoline/core/utils/geo_utils.dart';

void main() {
  group('LoopLapDetector', () {
    test('inGeofence is true within radius, false outside', () {
      expect(inGeofence(10, 10, 10, 10, 50), isTrue);
      // ~111m north — outside a 50m geofence.
      expect(inGeofence(10.001, 10, 10, 10, 50), isFalse);
    });

    test('does not complete a lap before leaving the init zone', () {
      final detector = LoopLapDetector(
        initLat: 10,
        initLng: 10,
        geofenceRadiusM: 50,
      );
      final base = DateTime(2026, 1, 1);
      detector.startLap(base);

      // Stays inside the init geofence the whole time.
      final completed = detector.feed(
        lat: 10.0001,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 5)),
      );
      expect(completed, isFalse);
    });

    test('does not complete a lap if re-entry is too soon / too short', () {
      final detector = LoopLapDetector(
        initLat: 10,
        initLng: 10,
        geofenceRadiusM: 50,
        minLapDistanceMeters: 200,
        minLapDuration: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1);
      detector.startLap(base);

      // Exit the zone.
      detector.feed(
        lat: 10.002, // ~222m away
        lng: 10,
        timestamp: base.add(const Duration(seconds: 5)),
      );
      // Re-enter almost immediately — too soon and too short a loop.
      final completed = detector.feed(
        lat: 10,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 8)),
      );
      expect(completed, isFalse);
    });

    test('completes a lap after exit + re-entry with enough time/distance', () {
      final detector = LoopLapDetector(
        initLat: 10,
        initLng: 10,
        geofenceRadiusM: 50,
        minLapDistanceMeters: 200,
        minLapDuration: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1);
      detector.startLap(base);

      // Leave the zone.
      var completed = detector.feed(
        lat: 10.002,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 5)),
      );
      expect(completed, isFalse);

      // Ride further away, accumulating distance.
      completed = detector.feed(
        lat: 10.004,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 20)),
      );
      expect(completed, isFalse);

      // Come back into the init zone after >= 30s and >= 200m covered.
      completed = detector.feed(
        lat: 10.0001,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 40)),
      );
      expect(completed, isTrue);
    });

    test('startLap resets distance/time tracking for the next lap', () {
      final detector = LoopLapDetector(
        initLat: 10,
        initLng: 10,
        geofenceRadiusM: 50,
        minLapDistanceMeters: 200,
        minLapDuration: const Duration(seconds: 30),
      );
      final base = DateTime(2026, 1, 1);
      detector.startLap(base);

      detector.feed(
        lat: 10.004,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 20)),
      );
      final firstLapCompleted = detector.feed(
        lat: 10.0001,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 40)),
      );
      expect(firstLapCompleted, isTrue);

      // Start the next lap; being inside the zone immediately should not
      // spuriously complete another lap.
      detector.startLap(base.add(const Duration(seconds: 40)));
      final immediatelyCompleted = detector.feed(
        lat: 10.0001,
        lng: 10,
        timestamp: base.add(const Duration(seconds: 41)),
      );
      expect(immediatelyCompleted, isFalse);
    });
  });
}
