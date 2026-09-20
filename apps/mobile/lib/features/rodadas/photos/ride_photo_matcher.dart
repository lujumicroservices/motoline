import '../../../core/models/track_point.dart';
import '../../../core/utils/geo_utils.dart';

const _preRideSlack = Duration(minutes: 5);
const _postRideSlack = Duration(minutes: 15);
const _gpsSnapMeters = 150.0;
const _gpsRejectMeters = 2000.0;
/// When the recorded line has holes, nearest-point can be kilometres away
/// even if the photo GPS is on the road. Compare to the time-interpolated
/// position before rejecting.
const _gpsHoleRejectMeters = 5000.0;
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
    if (nearest.$1 <= _gpsSnapMeters) {
      return PhotoTrackMatch(
        accepted: true,
        latitude: photoLat,
        longitude: photoLng,
      );
    }
    if (nearest.$1 <= _gpsRejectMeters) {
      return PhotoTrackMatch(
        accepted: true,
        latitude: nearest.$2.latitude,
        longitude: nearest.$2.longitude,
      );
    }
    final alongTrack = _interpolateByTime(points, takenAt);
    final holeDist = haversineMeters(
      photoLat,
      photoLng,
      alongTrack.latitude,
      alongTrack.longitude,
    );
    if (holeDist <= _gpsHoleRejectMeters) {
      return PhotoTrackMatch(
        accepted: true,
        latitude: photoLat,
        longitude: photoLng,
      );
    }
    return PhotoTrackMatch.farFromLine;
  }

  final byTime = _interpolateByTime(points, takenAt);
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

/// User picked these in the system Photo Picker — always keep them.
/// Clamp EXIF time into the ride so we can still pin GPS on the line.
PhotoTrackMatch matchUserPickedPhotoToTrack({
  DateTime? takenAt,
  double? photoLat,
  double? photoLng,
  required List<TrackPoint> points,
  required DateTime rideStart,
  required DateTime rideEnd,
}) {
  final raw = takenAt ?? rideEnd;
  final clamped = raw.isBefore(rideStart)
      ? rideStart
      : (raw.isAfter(rideEnd) ? rideEnd : raw);
  final match = matchPhotoToTrack(
    takenAt: clamped,
    photoLat: photoLat,
    photoLng: photoLng,
    points: points,
    rideStart: rideStart,
    rideEnd: rideEnd,
  );
  if (match.accepted) return match;
  if (points.isEmpty) {
    return PhotoTrackMatch(
      accepted: true,
      latitude: photoLat,
      longitude: photoLng,
      reason: 'picked',
    );
  }
  final last = points.last;
  return PhotoTrackMatch(
    accepted: true,
    latitude: photoLat ?? last.latitude,
    longitude: photoLng ?? last.longitude,
    reason: 'picked',
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

/// Pin on the polyline by timestamp so GPS dropouts don't look like "off route".
TrackPoint _interpolateByTime(List<TrackPoint> points, DateTime takenAt) {
  if (points.length == 1) return points.first;
  if (!takenAt.isAfter(points.first.timestamp)) return points.first;
  if (!takenAt.isBefore(points.last.timestamp)) return points.last;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    if (takenAt.isAfter(b.timestamp)) continue;
    final span = b.timestamp.difference(a.timestamp).inMilliseconds;
    if (span <= 0) return b;
    final t = takenAt.difference(a.timestamp).inMilliseconds / span;
    return TrackPoint(
      id: a.id,
      rideId: a.rideId,
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: a.longitude + (b.longitude - a.longitude) * t,
      timestamp: takenAt,
    );
  }
  return _nearestByTime(points, takenAt);
}
