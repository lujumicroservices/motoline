import '../../../core/models/track_point.dart';
import '../../../core/utils/geo_utils.dart';

const _preRideSlack = Duration(minutes: 5);
const _postRideSlack = Duration(minutes: 15);
const _gpsSnapMeters = 150.0;
const _gpsRejectMeters = 2000.0;
const _timeSnap = Duration(seconds: 30);

class PhotoTrackMatch {
  const PhotoTrackMatch({
    required this.accepted,
    this.latitude,
    this.longitude,
    this.reason,
  });

  final bool accepted;
  final double? latitude;
  final double? longitude;
  final String? reason;

  static const outsideWindow = PhotoTrackMatch(
    accepted: false,
    reason: 'outside_window',
  );

  static const farFromLine = PhotoTrackMatch(
    accepted: false,
    reason: 'far_from_line',
  );
}

/// Decide whether a phone photo belongs on this ride and where to pin it.
PhotoTrackMatch matchPhotoToTrack({
  required DateTime takenAt,
  double? photoLat,
  double? photoLng,
  required List<TrackPoint> points,
  required DateTime rideStart,
  required DateTime rideEnd,
}) {
  final windowStart = rideStart.subtract(_preRideSlack);
  final windowEnd = rideEnd.add(_postRideSlack);
  if (takenAt.isBefore(windowStart) || takenAt.isAfter(windowEnd)) {
    return PhotoTrackMatch.outsideWindow;
  }
  if (points.isEmpty) {
    if (photoLat != null && photoLng != null) {
      return PhotoTrackMatch(
        accepted: true,
        latitude: photoLat,
        longitude: photoLng,
      );
    }
    return const PhotoTrackMatch(accepted: true);
  }

  final hasGps = photoLat != null && photoLng != null;
  if (hasGps) {
    final nearest = _nearestByDistance(points, photoLat, photoLng);
    if (nearest.$1 > _gpsRejectMeters) {
      return PhotoTrackMatch.farFromLine;
    }
    if (nearest.$1 <= _gpsSnapMeters) {
      return PhotoTrackMatch(
        accepted: true,
        latitude: photoLat,
        longitude: photoLng,
      );
    }
    return PhotoTrackMatch(
      accepted: true,
      latitude: nearest.$2.latitude,
      longitude: nearest.$2.longitude,
    );
  }

  final byTime = _nearestByTime(points, takenAt);
  final delta = takenAt.difference(byTime.timestamp).abs();
  if (delta > _timeSnap &&
      (takenAt.isBefore(rideStart) || takenAt.isAfter(rideEnd))) {
    return PhotoTrackMatch.outsideWindow;
  }
  return PhotoTrackMatch(
    accepted: true,
    latitude: byTime.latitude,
    longitude: byTime.longitude,
  );
}

(double, TrackPoint) _nearestByDistance(
  List<TrackPoint> points,
  double lat,
  double lng,
) {
  var best = points.first;
  var bestD = double.infinity;
  for (final p in points) {
    final d = haversineMeters(lat, lng, p.latitude, p.longitude);
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return (bestD, best);
}

TrackPoint _nearestByTime(List<TrackPoint> points, DateTime takenAt) {
  var best = points.first;
  var bestD = takenAt.difference(best.timestamp).abs();
  for (final p in points) {
    final d = takenAt.difference(p.timestamp).abs();
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}
