/// Indices where a GPS time gap starts (point [i] is first sample after a gap).
List<int> gpsGapStartIndices(
  List<DateTime> timestamps, {
  Duration maxGap = const Duration(seconds: 8),
}) {
  if (timestamps.length < 2) return const [];
  final gaps = <int>[];
  for (var i = 1; i < timestamps.length; i++) {
    if (timestamps[i].difference(timestamps[i - 1]) > maxGap) {
      gaps.add(i);
    }
  }
  return gaps;
}

/// Split a track into contiguous segments by time gaps.
List<List<T>> splitTrackByGaps<T>(
  List<T> points,
  DateTime Function(T) timestampOf, {
  Duration maxGap = const Duration(seconds: 8),
}) {
  if (points.isEmpty) return const [];
  final segments = <List<T>>[];
  var current = <T>[points.first];
  for (var i = 1; i < points.length; i++) {
    final gap = timestampOf(points[i]).difference(timestampOf(points[i - 1]));
    if (gap > maxGap) {
      segments.add(current);
      current = <T>[points[i]];
    } else {
      current.add(points[i]);
    }
  }
  segments.add(current);
  return segments;
}
