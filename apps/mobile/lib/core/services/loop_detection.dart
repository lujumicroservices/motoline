import '../models/route_loop.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'loop_session_controller.dart';

/// Finds closed-loop candidates on a GPS track (return near start after
/// covering enough distance / time).
List<DetectedLoopCandidate> detectClosedLoops({
  required String rideId,
  required List<TrackPoint> points,
  double closeRadiusM = kLoopGeofenceRadiusMeters,
  double minPathMeters = kLoopMinLapDistanceMeters,
  Duration minDuration = kLoopMinLapDuration,
  int maxCandidates = 5,
}) {
  if (points.length < 30) return const [];

  final candidates = <DetectedLoopCandidate>[];
  // Sample start anchors every ~N points to keep work bounded.
  const stride = 8;
  for (var i = 0; i < points.length - 20; i += stride) {
    final start = points[i];
    var path = 0.0;
    var found = false;
    for (var j = i + 1; j < points.length; j++) {
      path += haversineMeters(
        points[j - 1].latitude,
        points[j - 1].longitude,
        points[j].latitude,
        points[j].longitude,
      );
      final elapsed = points[j].timestamp.difference(start.timestamp);
      if (path < minPathMeters || elapsed < minDuration) continue;

      final close = haversineMeters(
        start.latitude,
        start.longitude,
        points[j].latitude,
        points[j].longitude,
      );
      if (close <= closeRadiusM) {
        candidates.add(
          DetectedLoopCandidate(
            rideId: rideId,
            startIndex: i,
            endIndex: j,
            initLat: start.latitude,
            initLng: start.longitude,
            endLat: points[j].latitude,
            endLng: points[j].longitude,
            pathMeters: path,
            duration: elapsed,
          ),
        );
        found = true;
        // Skip ahead past this loop so we don't stack near-duplicates.
        i = j;
        break;
      }
    }
    if (found && candidates.length >= maxCandidates) break;
  }

  // Prefer longer paths first.
  candidates.sort((a, b) => b.pathMeters.compareTo(a.pathMeters));
  if (candidates.length <= maxCandidates) return candidates;
  return candidates.sublist(0, maxCandidates);
}
