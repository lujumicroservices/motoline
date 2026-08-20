import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/features/rodadas/photos/ride_photo_matcher.dart';

void main() {
  final start = DateTime(2026, 8, 19, 10);
  final end = start.add(const Duration(hours: 2));
  final points = [
    TrackPoint(
      id: 1,
      rideId: 'r',
      latitude: 20.67,
      longitude: -103.35,
      timestamp: start.add(const Duration(minutes: 10)),
    ),
    TrackPoint(
      id: 2,
      rideId: 'r',
      latitude: 20.68,
      longitude: -103.36,
      timestamp: start.add(const Duration(minutes: 40)),
    ),
  ];

  test('accepts photo with GPS on the line', () {
    final match = matchPhotoToTrack(
      takenAt: start.add(const Duration(minutes: 10)),
      photoLat: 20.6702,
      photoLng: -103.3501,
      points: points,
      rideStart: start,
      rideEnd: end,
    );
    expect(match.accepted, isTrue);
    expect(match.latitude, closeTo(20.6702, 0.0001));
  });

  test('rejects GPS far from the line', () {
    final match = matchPhotoToTrack(
      takenAt: start.add(const Duration(minutes: 10)),
      photoLat: 21.2,
      photoLng: -104.0,
      points: points,
      rideStart: start,
      rideEnd: end,
    );
    expect(match.accepted, isFalse);
    expect(match.reason, 'far_from_line');
  });

  test('pins by time when EXIF has no GPS', () {
    final match = matchPhotoToTrack(
      takenAt: start.add(const Duration(minutes: 40)),
      points: points,
      rideStart: start,
      rideEnd: end,
    );
    expect(match.accepted, isTrue);
    expect(match.latitude, 20.68);
    expect(match.longitude, -103.36);
  });

  test('rejects photos outside the ride window', () {
    final match = matchPhotoToTrack(
      takenAt: start.subtract(const Duration(hours: 5)),
      photoLat: 20.67,
      photoLng: -103.35,
      points: points,
      rideStart: start,
      rideEnd: end,
    );
    expect(match.accepted, isFalse);
  });
}
