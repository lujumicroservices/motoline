import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/features/reel/reel_pauses.dart';
import 'package:motoline/features/reel/reel_timeline.dart';

TrackPoint _pt(
  int id,
  DateTime at, {
  double lat = 20.67,
  double lng = -103.35,
}) {
  return TrackPoint(
    id: id,
    rideId: 'r',
    latitude: lat,
    longitude: lng,
    timestamp: at,
  );
}

void main() {
  final start = DateTime(2026, 8, 20, 10);

  List<TrackPoint> routeWithGap(Duration gap) {
    return [
      _pt(1, start),
      _pt(2, start.add(const Duration(seconds: 4))),
      _pt(3, start.add(const Duration(seconds: 8))),
      _pt(
        4,
        start.add(const Duration(seconds: 8) + gap),
        lat: 20.6704,
        lng: -103.3504,
      ),
      _pt(
        5,
        start.add(const Duration(seconds: 12) + gap),
        lat: 20.6708,
        lng: -103.3508,
      ),
    ];
  }

  test('gaps under 45s are not rest stops', () {
    final pauses = detectRidePauses(routeWithGap(const Duration(seconds: 30)));
    expect(pauses, isEmpty);
  });

  test('gaps of 45s+ become a pause at the last moving point', () {
    final pauses = detectRidePauses(routeWithGap(const Duration(seconds: 60)));
    expect(pauses, hasLength(1));
    expect(pauses.first.latitude, 20.67);
    expect(pauses.first.longitude, -103.35);
    expect(pauses.first.duration, const Duration(seconds: 60));
  });

  test('capPausesForLength keeps the longest then restores route order', () {
    final points = [
      _pt(1, start),
      _pt(2, start.add(const Duration(seconds: 4))),
      _pt(3, start.add(const Duration(seconds: 94))), // 90s pause
      _pt(4, start.add(const Duration(seconds: 98))),
      _pt(5, start.add(const Duration(seconds: 248))), // 150s pause
      _pt(6, start.add(const Duration(seconds: 252))),
      _pt(7, start.add(const Duration(seconds: 312))), // 60s pause
      _pt(8, start.add(const Duration(seconds: 316))),
    ];
    final all = detectRidePauses(points);
    expect(all, hasLength(3));
    final capped = capPausesForLength(all, ReelLength.short);
    expect(capped, hasLength(2));
    expect(capped.first.duration, const Duration(seconds: 90));
    expect(capped.last.duration, const Duration(seconds: 150));
    expect(capped.first.index, 1);
    expect(capped.last.index, 2);
  });

  test('photo during the pause window clusters to that stop', () {
    final pauses = detectRidePauses(routeWithGap(const Duration(minutes: 8)));
    final clustered = clusterAlbumToPauses(
      pauses: pauses,
      photos: [
        ReelAlbumItem(
          id: 'a',
          takenAt: start.add(const Duration(seconds: 20)),
        ),
      ],
    );
    expect(clustered.photosByPause.first, hasLength(1));
    expect(clustered.onRoute, isEmpty);
  });

  test('photo near the pause pin clusters even after the ride', () {
    final pauses = detectRidePauses(routeWithGap(const Duration(minutes: 8)));
    final clustered = clusterAlbumToPauses(
      pauses: pauses,
      photos: [
        ReelAlbumItem(
          id: 'added',
          takenAt: DateTime(2026, 8, 21),
          latitude: 20.6701,
          longitude: -103.3501,
        ),
      ],
    );
    expect(clustered.photosByPause.first.single.id, 'added');
    expect(clustered.onRoute, isEmpty);
  });

  test('photo far from stops stays on-route', () {
    final pauses = detectRidePauses(routeWithGap(const Duration(minutes: 8)));
    final clustered = clusterAlbumToPauses(
      pauses: pauses,
      photos: [
        ReelAlbumItem(
          id: 'road',
          takenAt: start.add(const Duration(seconds: 4)),
          latitude: 21.2,
          longitude: -104.0,
        ),
      ],
    );
    expect(clustered.photosByPause.first, isEmpty);
    expect(clustered.onRoute.single.id, 'road');
  });

  test('defaultSelectedPhotoIds respects per-pause and max caps', () {
    final pauses = [
      DetectedPause(
        index: 1,
        latitude: 20.67,
        longitude: -103.35,
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 8)),
      ),
    ];
    final clustered = clusterAlbumToPauses(
      pauses: pauses,
      photos: [
        for (var i = 0; i < 5; i++)
          ReelAlbumItem(
            id: 'p$i',
            takenAt: start.add(Duration(minutes: i)),
          ),
        const ReelAlbumItem(id: 'road'),
      ],
    );
    expect(
      defaultSelectedPhotoIds(clustered: clustered, maxPhotos: 4),
      ['p0', 'p1', 'p2', 'road'],
    );
  });
}
