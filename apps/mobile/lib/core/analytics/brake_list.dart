import 'brake_detection.dart';

/// Full-ride list: strongest first, keep the list short.
const overviewBrakeListCap = 8;

/// Zoomed stretch: show the sequence; cap only if the window is still huge.
const zoomedBrakeListCap = 20;

enum BrakeListSort {
  strongestFirst,
  chronological,
}

class BrakeListSlice {
  const BrakeListSlice({
    required this.events,
    required this.hiddenCount,
  });

  /// Events to render (already ranked / capped).
  final List<BrakeEvent> events;

  /// Events in the pool that did not make the cap (not the Pro gate).
  final int hiddenCount;
}

bool brakeOverlapsSeconds({
  required double startSeconds,
  required double endSeconds,
  required double windowStart,
  required double windowEnd,
}) {
  final a = startSeconds <= endSeconds ? startSeconds : endSeconds;
  final b = startSeconds <= endSeconds ? endSeconds : startSeconds;
  final lo = windowStart <= windowEnd ? windowStart : windowEnd;
  final hi = windowStart <= windowEnd ? windowEnd : windowStart;
  return a <= hi && b >= lo;
}

/// Rank and cap brake events for the Ride Lab list. Does not load GPS.
BrakeListSlice visibleBrakeEvents(
  List<BrakeEvent> events, {
  required int cap,
  BrakeListSort sort = BrakeListSort.strongestFirst,
  double Function(int index)? secondsForIndex,
  double? windowStartSeconds,
  double? windowEndSeconds,
}) {
  var pool = events;
  if (windowStartSeconds != null &&
      windowEndSeconds != null &&
      secondsForIndex != null) {
    pool = [
      for (final e in events)
        if (brakeOverlapsSeconds(
          startSeconds: secondsForIndex(e.startIndex),
          endSeconds: secondsForIndex(e.endIndex),
          windowStart: windowStartSeconds,
          windowEnd: windowEndSeconds,
        ))
          e,
    ];
  }

  if (pool.isEmpty) {
    return const BrakeListSlice(events: [], hiddenCount: 0);
  }

  final ranked = [...pool];
  if (ranked.length <= cap) {
    _sortBrakeEvents(ranked, sort);
    return BrakeListSlice(events: ranked, hiddenCount: 0);
  }

  ranked.sort(_compareStrongest);
  final kept = ranked.sublist(0, cap);
  _sortBrakeEvents(kept, sort);
  return BrakeListSlice(
    events: kept,
    hiddenCount: pool.length - cap,
  );
}

int _compareStrongest(BrakeEvent a, BrakeEvent b) {
  final d = b.peakDecelMps2.compareTo(a.peakDecelMps2);
  if (d != 0) return d;
  return a.startIndex.compareTo(b.startIndex);
}

void _sortBrakeEvents(List<BrakeEvent> events, BrakeListSort sort) {
  switch (sort) {
    case BrakeListSort.strongestFirst:
      events.sort(_compareStrongest);
    case BrakeListSort.chronological:
      events.sort((a, b) => a.startIndex.compareTo(b.startIndex));
  }
}
