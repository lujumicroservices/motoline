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

/// True when (lat, lng) is within [radiusM] meters of (centerLat, centerLng).
bool inGeofence(
  double lat,
  double lng,
  double centerLat,
  double centerLng,
  double radiusM,
) {
  return haversineMeters(lat, lng, centerLat, centerLng) <= radiusM;
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

/// Duration / elapsed with millisecond precision (3 decimal places).
/// Examples: `01:23.456`, `1:02:03.070`.
String formatElapsedPrecise(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '00:00.000';
  final totalMs = (seconds.abs() * 1000).round();
  final ms = totalMs % 1000;
  final totalSec = totalMs ~/ 1000;
  final s = totalSec % 60;
  final m = (totalSec ~/ 60) % 60;
  final h = totalSec ~/ 3600;
  final frac = ms.toString().padLeft(3, '0');
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$frac';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.$frac';
}

String formatDurationPrecise(Duration d) =>
    formatElapsedPrecise(d.inMilliseconds / 1000.0);

/// Inclusive index window for points that fall inside a lat/lng box.
///
/// Bridges short GPS outliers (outside spikes) so a drawn box stays one segment.
/// When [preferLat]/[preferLng] are set (box center), prefers the run whose
/// centroid is closest to that point among long candidates (multi-pass loops).
({int start, int end, int insideCount})? segmentIndicesInBounds({
  required List<TrackPoint> points,
  required bool Function(TrackPoint point) isInside,
  int maxBridgeOutside = 3,
  Duration maxBridgeGap = const Duration(seconds: 3),
  double? preferLat,
  double? preferLng,
}) {
  if (points.length < 2) return null;

  final insideFlags = List<bool>.generate(points.length, (i) => isInside(points[i]));
  var insideCount = 0;
  for (final v in insideFlags) {
    if (v) insideCount++;
  }
  if (insideCount < 2) return null;

  // Expand "inside" by bridging short outside streaks between inside samples.
  final bridged = List<bool>.from(insideFlags);
  var i = 0;
  while (i < points.length) {
    if (!insideFlags[i]) {
      i++;
      continue;
    }
    var j = i + 1;
    while (j < points.length && insideFlags[j]) {
      j++;
    }
    // j is first outside (or length). Look ahead for next inside within bridge.
    if (j < points.length && !insideFlags[j]) {
      var k = j;
      var outsideN = 0;
      while (k < points.length && !insideFlags[k]) {
        outsideN++;
        k++;
      }
      if (k < points.length &&
          outsideN <= maxBridgeOutside &&
          points[k].timestamp.difference(points[j - 1].timestamp) <=
              maxBridgeGap) {
        var hopOk = true;
        for (var t = j; t <= k; t++) {
          final d = haversineMeters(
            points[t - 1].latitude,
            points[t - 1].longitude,
            points[t].latitude,
            points[t].longitude,
          );
          // Don't bridge GPS teleports / other loop passes.
          if (d > 60) {
            hopOk = false;
            break;
          }
        }
        if (hopOk) {
          for (var t = j; t < k; t++) {
            bridged[t] = true;
          }
        }
      }
    }
    i = j;
  }

  final runs = <({int start, int end, int len})>[];
  var runStart = -1;
  for (var idx = 0; idx < bridged.length; idx++) {
    if (bridged[idx]) {
      if (runStart < 0) runStart = idx;
    } else if (runStart >= 0) {
      final end = idx - 1;
      if (end > runStart) {
        runs.add((start: runStart, end: end, len: end - runStart + 1));
      }
      runStart = -1;
    }
  }
  if (runStart >= 0) {
    final end = bridged.length - 1;
    if (end > runStart) {
      runs.add((start: runStart, end: end, len: end - runStart + 1));
    }
  }

  if (runs.isEmpty) return null;

  // Prefer longest; break ties / multi-pass with proximity to box center.
  ({int start, int end, int len})? best;
  var bestScore = -1.0;
  final minLen = runs.map((r) => r.len).reduce(math.max);
  final longEnough = (minLen * 0.55).ceil().clamp(2, minLen);

  for (final run in runs) {
    if (run.len < 2) continue;
    var score = run.len.toDouble();
    if (preferLat != null && preferLng != null && run.len >= longEnough) {
      var sumLat = 0.0;
      var sumLng = 0.0;
      var n = 0;
      for (var t = run.start; t <= run.end; t++) {
        if (!insideFlags[t]) continue;
        sumLat += points[t].latitude;
        sumLng += points[t].longitude;
        n++;
      }
      if (n > 0) {
        final d = haversineMeters(
          sumLat / n,
          sumLng / n,
          preferLat,
          preferLng,
        );
        // Closer to box center wins among similarly long runs.
        score += 100000.0 / (1.0 + d);
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = run;
    }
  }

  if (best == null) return null;

  // Trim bridged edges back to real inside samples for cleaner metrics.
  var start = best.start;
  var end = best.end;
  while (start < end && !insideFlags[start]) {
    start++;
  }
  while (end > start && !insideFlags[end]) {
    end--;
  }
  if (end <= start) return null;

  return (start: start, end: end, insideCount: insideCount);
}

double _toRad(double deg) => deg * math.pi / 180;
