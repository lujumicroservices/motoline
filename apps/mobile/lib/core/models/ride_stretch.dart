import '../utils/geo_utils.dart';
import 'track_point.dart';

/// Matches [MotionPatternDetector.pauseSpeedThresholdMps] (~8 km/h).
/// A GPS hole while rolling faster than this is signal loss, not a new tramo.
const rideStretchMaxImpliedSpeedMps = 2.2;

/// Aligned with auto-pause's 12s slow window so sparse GNSS does not split.
const rideStretchDefaultMaxGap = Duration(seconds: 12);

/// One recorded stretch inside a ride, split on **stops** (slow implied
/// speed across a time gap), not on signal-loss while moving.
/// Not a database row — derived from the flat [track_points] list.
class RideStretch {
  const RideStretch({
    required this.index,
    required this.points,
  });

  /// 1-based index for UI ("Tramo 1").
  final int index;
  final List<TrackPoint> points;

  DateTime get startedAt => points.first.timestamp;
  DateTime get endedAt => points.last.timestamp;
  Duration get duration => endedAt.difference(startedAt);
  double get distanceMeters => pathDistanceMeters(points);
  double get distanceKm => distanceMeters / 1000.0;
  int get pointCount => points.length;
}

/// Split a session's GPS into stretches at rest-like pauses.
///
/// A new stretch starts only when consecutive samples are farther apart than
/// [maxGap] **and** implied speed across that hole is below
/// [maxImpliedSpeedMps] (stopped / crawling). Highway tunnels and urban
/// GNSS dropouts stay in the same tramo; the map still draws those holes via
/// [splitByGpsGaps].
List<RideStretch> rideStretchesFrom(
  List<TrackPoint> points, {
  Duration maxGap = rideStretchDefaultMaxGap,
  double maxImpliedSpeedMps = rideStretchMaxImpliedSpeedMps,
}) {
  if (points.isEmpty) return const [];
  final groups = _collapseSingletonGroups(
    splitByStopGaps(
      points,
      maxGap: maxGap,
      maxImpliedSpeedMps: maxImpliedSpeedMps,
    ),
  );
  return [
    for (var i = 0; i < groups.length; i++)
      RideStretch(index: i + 1, points: groups[i]),
  ];
}

/// Time-gap split that ignores moving signal-loss.
List<List<TrackPoint>> splitByStopGaps(
  List<TrackPoint> points, {
  Duration maxGap = rideStretchDefaultMaxGap,
  double maxImpliedSpeedMps = rideStretchMaxImpliedSpeedMps,
}) {
  if (points.isEmpty) return const [];
  final segments = <List<TrackPoint>>[];
  var current = <TrackPoint>[points.first];

  for (var i = 1; i < points.length; i++) {
    final prev = points[i - 1];
    final next = points[i];
    final gap = next.timestamp.difference(prev.timestamp);
    var split = false;
    if (gap > maxGap) {
      final dtSec = gap.inMilliseconds / 1000.0;
      final jump = haversineMeters(
        prev.latitude,
        prev.longitude,
        next.latitude,
        next.longitude,
      );
      final impliedMps = dtSec <= 0 ? 0.0 : jump / dtSec;
      split = impliedMps < maxImpliedSpeedMps;
    }
    if (split) {
      segments.add(current);
      current = <TrackPoint>[next];
    } else {
      current.add(next);
    }
  }
  segments.add(current);
  return segments;
}

/// Absorb a lone sample (GPS blip after a pause) into the previous stretch.
List<List<TrackPoint>> _collapseSingletonGroups(
  List<List<TrackPoint>> groups,
) {
  if (groups.length < 2) return groups;
  final out = <List<TrackPoint>>[List<TrackPoint>.from(groups.first)];
  for (var i = 1; i < groups.length; i++) {
    final group = groups[i];
    if (group.length == 1) {
      out.last.add(group.first);
    } else {
      out.add(List<TrackPoint>.from(group));
    }
  }
  return out;
}
