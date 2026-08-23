/// Level-of-detail helpers for long GPS / lean series.
/// Overview never replaces stored ride distance — it is display-only.

/// 0-based indices including first and last, at most [maxPoints] samples.
List<int> overviewIndices(int count, int maxPoints) {
  if (count <= 0) return const [];
  if (maxPoints <= 1) return [0, if (count > 1) count - 1];
  if (count <= maxPoints) {
    return [for (var i = 0; i < count; i++) i];
  }
  final step = (count - 1) / (maxPoints - 1);
  final out = <int>[];
  var last = -1;
  for (var i = 0; i < maxPoints; i++) {
    final idx = (i * step).round().clamp(0, count - 1);
    if (idx != last) out.add(idx);
    last = idx;
  }
  if (out.first != 0) out.insert(0, 0);
  if (out.last != count - 1) out.add(count - 1);
  return out;
}

List<T> pickOverview<T>(List<T> items, int maxPoints) {
  final idx = overviewIndices(items.length, maxPoints);
  return [for (final i in idx) items[i]];
}

/// Inclusive timestamp window (milliseconds since epoch).
List<T> filterTimeWindow<T>(
  List<T> items,
  int Function(T item) timestampMs,
  int fromMs,
  int toMs,
) {
  if (fromMs > toMs) {
    final swap = fromMs;
    fromMs = toMs;
    toMs = swap;
  }
  return [
    for (final item in items)
      if (timestampMs(item) >= fromMs && timestampMs(item) <= toMs) item,
  ];
}

/// Nearest index by timestamp; empty list → 0.
///
/// [items] must be sorted by timestamp (overview / GPS series). Binary search
/// so remapping lab events onto ~1k map vertices stays cheap.
int nearestIndexByTime<T>(
  List<T> items,
  int Function(T item) timestampMs,
  int targetMs,
) {
  if (items.isEmpty) return 0;
  var lo = 0;
  var hi = items.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (timestampMs(items[mid]) < targetMs) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo > 0) {
    final left = timestampMs(items[lo - 1]);
    final right = timestampMs(items[lo]);
    if ((targetMs - left).abs() <= (right - targetMs).abs()) {
      return lo - 1;
    }
  }
  return lo;
}
