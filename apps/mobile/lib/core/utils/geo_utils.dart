import 'dart:math' as math;

import '../models/track_point.dart';

/// Haversine distance in meters between two WGS84 points.
double haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadius = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double pathDistanceMeters(List<TrackPoint> points) {
  if (points.length < 2) return 0;
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineMeters(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
  }
  return total;
}

/// Marks gaps where consecutive samples are farther apart in time than [maxGap].
List<List<TrackPoint>> splitByGpsGaps(
  List<TrackPoint> points, {
  Duration maxGap = const Duration(seconds: 8),
}) {
  if (points.isEmpty) return const [];
  final segments = <List<TrackPoint>>[];
  var current = <TrackPoint>[points.first];

  for (var i = 1; i < points.length; i++) {
    final gap = points[i].timestamp.difference(points[i - 1].timestamp);
    if (gap > maxGap) {
      segments.add(current);
      current = <TrackPoint>[points[i]];
    } else {
      current.add(points[i]);
    }
  }
  segments.add(current);
  return segments;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

/// Inclusive index window for points that fall inside a lat/lng box.
///
/// Prefers the longest contiguous run inside the box (best for loops that
/// re-enter the same area). Returns null when fewer than 2 points qualify.
({int start, int end, int insideCount})? segmentIndicesInBounds({
  required List<TrackPoint> points,
  required bool Function(TrackPoint point) isInside,
}) {
  if (points.length < 2) return null;

  var bestStart = -1;
  var bestEnd = -1;
  var bestLen = 0;
  var runStart = -1;
  var insideCount = 0;

  for (var i = 0; i < points.length; i++) {
    if (isInside(points[i])) {
      insideCount++;
      if (runStart < 0) runStart = i;
      final len = i - runStart + 1;
      if (len > bestLen) {
        bestLen = len;
        bestStart = runStart;
        bestEnd = i;
      }
    } else {
      runStart = -1;
    }
  }

  if (bestStart < 0 || bestEnd <= bestStart) return null;
  return (start: bestStart, end: bestEnd, insideCount: insideCount);
}

double _toRad(double deg) => deg * math.pi / 180;
