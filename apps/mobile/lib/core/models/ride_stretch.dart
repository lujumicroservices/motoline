import '../utils/geo_utils.dart';
import 'track_point.dart';

/// One recorded stretch inside a ride, split on GPS time gaps (auto-pause).
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

/// Split a session's GPS into stretches at pauses longer than [maxGap].
List<RideStretch> rideStretchesFrom(
  List<TrackPoint> points, {
  Duration maxGap = const Duration(seconds: 8),
}) {
  if (points.isEmpty) return const [];
  final groups = splitByGpsGaps(points, maxGap: maxGap);
  return [
    for (var i = 0; i < groups.length; i++)
      RideStretch(index: i + 1, points: groups[i]),
  ];
}
