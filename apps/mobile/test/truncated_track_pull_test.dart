import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/ride_analytics.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/services/ride_sync_service.dart';

TrackPoint _pt(int i, {required double lat, required double lng}) {
  return TrackPoint(
    id: i,
    rideId: 'r1',
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 8, 20, 22, 0, i),
  );
}

void main() {
  test('truncated GPS pull uses stored ride distance', () {
    final ride = Ride(
      id: 'r1',
      startedAt: DateTime.utc(2026, 8, 20, 22, 9),
      endedAt: DateTime.utc(2026, 8, 20, 23, 51),
      status: RideStatus.completed,
      distanceMeters: 120580,
      pointCount: 5450,
    );
    final points = [
      _pt(0, lat: 21.26, lng: -103.16),
      _pt(1, lat: 21.27, lng: -103.16),
      _pt(2, lat: 21.28, lng: -103.16),
    ];
    final a = RideAnalytics(ride: ride, points: points);
    expect(a.distanceKm, closeTo(120.58, 0.01));
    expect(a.duration.inMinutes, greaterThan(90));
  });

  test('garage pull skips GPS when local already has a track', () {
    expect(
      RideSyncService.skipTrackDownload(
        localPointCount: 12,
        tracksOnlyIfLocalEmpty: true,
      ),
      isTrue,
    );
    expect(
      RideSyncService.skipTrackDownload(
        localPointCount: 0,
        tracksOnlyIfLocalEmpty: true,
      ),
      isFalse,
    );
    expect(
      RideSyncService.skipTrackDownload(
        localPointCount: 12,
        tracksOnlyIfLocalEmpty: false,
      ),
      isFalse,
    );
  });

  test('fillGapsOnly replaces local when cloud GPS is denser', () {
    final local = [_pt(0, lat: 21.26, lng: -103.16)];
    final cloud = [
      _pt(0, lat: 21.26, lng: -103.16),
      _pt(1, lat: 21.27, lng: -103.16),
    ];
    expect(
      RideSyncService.shouldKeepLocalTrack(
        local: local,
        cloud: cloud,
        policy: TrackPullPolicy.fillGapsOnly,
      ),
      isFalse,
    );
  });
}
