import '../models/cloud_models.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'track_overlap.dart';

/// Two tracks clipped to the same geographic corridor (same road section).
class AlignedTrackPair {
  const AlignedTrackPair({
    required this.left,
    required this.right,
    required this.sharedMeters,
    required this.matchPctLeft,
  });

  final List<TrackPoint> left;
  final List<TrackPoint> right;
  final double sharedMeters;
  final double matchPctLeft;

  bool get isUsable => left.length >= 2 && right.length >= 2;
}

/// Convert a cloud track into local [TrackPoint]s for analytics / maps.
List<TrackPoint> trackPointsFromCloud(
  List<CloudTrackPoint> cloud, {
  String rideId = 'peer',
}) {
  return [
    for (var i = 0; i < cloud.length; i++)
      TrackPoint(
        id: null,
        rideId: rideId,
        latitude: cloud[i].latitude,
        longitude: cloud[i].longitude,
        timestamp: cloud[i].recordedAt,
        speedMps: cloud[i].speedMps,
        leanDegrees: cloud[i].leanDegrees,
      ),
  ];
}

/// Clip both full rides to shared corridor runs (for route compare maps).
AlignedTrackPair? alignSharedCorridor(
  List<TrackPoint> left,
  List<TrackPoint> right, {
  double corridorRadiusM = 40,
  double minRunMeters = 80,
}) {
  if (left.length < 2 || right.length < 2) return null;
  final overlap = TrackOverlapMatcher(
    corridorRadiusM: corridorRadiusM,
    minRunMeters: minRunMeters,
  ).compute(left, right);
  if (overlap.runs.isEmpty) return null;
  final a = TrackOverlapMatcher.pointsInRunsA(left, overlap);
  final b = TrackOverlapMatcher.pointsInRunsB(right, overlap);
  if (a.length < 2 || b.length < 2) return null;
  return AlignedTrackPair(
    left: a,
    right: b,
    sharedMeters: overlap.sharedMeters,
    matchPctLeft: overlap.matchPctA,
  );
}

/// Align a local corner window to the matching stretch on a peer track.
///
/// Returns the **same geographic section** on both sides (overlap of the
/// local corner with the peer ride), so lean/speed compare is fair.
AlignedTrackPair? alignCornerToPeer({
  required List<TrackPoint> localSamples,
  required int mapStartIndex,
  required int mapEndIndex,
  required List<TrackPoint> peerSamples,
  double corridorRadiusM = 45,
  double minRunMeters = 25,
}) {
  if (localSamples.length < 2 || peerSamples.length < 2) return null;
  final n = localSamples.length;
  final lo = mapStartIndex.clamp(0, n - 1);
  final hi = mapEndIndex.clamp(lo, n - 1);
  final window = localSamples.sublist(lo, hi + 1);
  if (window.length < 2) return null;

  final overlap = TrackOverlapMatcher(
    corridorRadiusM: corridorRadiusM,
    minRunMeters: minRunMeters,
    resampleStepM: 8,
  ).compute(window, peerSamples);

  final run = overlap.longestRun;
  if (run == null) return null;

  final left = window.sublist(
    run.aStartOrig.clamp(0, window.length - 1),
    run.aEndOrig.clamp(0, window.length - 1) + 1,
  );
  final right = peerSamples.sublist(
    run.bStartOrig.clamp(0, peerSamples.length - 1),
    run.bEndOrig.clamp(0, peerSamples.length - 1) + 1,
  );
  if (left.length < 2 || right.length < 2) return null;

  return AlignedTrackPair(
    left: left,
    right: right,
    sharedMeters: run.lengthMeters,
    matchPctLeft: overlap.matchPctA,
  );
}

/// Sample index at a given fraction of path length (0–1).
int indexAtPathFraction(List<TrackPoint> points, double t) {
  if (points.isEmpty) return 0;
  if (points.length == 1) return 0;
  final target = t.clamp(0.0, 1.0);
  final total = pathDistanceMeters(points);
  if (total <= 1) {
    return (target * (points.length - 1)).round().clamp(0, points.length - 1);
  }
  final goal = target * total;
  var acc = 0.0;
  for (var i = 1; i < points.length; i++) {
    final d = haversineMeters(
      points[i - 1].latitude,
      points[i - 1].longitude,
      points[i].latitude,
      points[i].longitude,
    );
    if (acc + d >= goal) {
      final w = d <= 0 ? 1.0 : (goal - acc) / d;
      return w < 0.5 ? i - 1 : i;
    }
    acc += d;
  }
  return points.length - 1;
}
