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
int nearestIndexByTime<T>(
  List<T> items,
  int Function(T item) timestampMs,
  int targetMs,
) {
  if (items.isEmpty) return 0;
  var best = 0;
  var bestDelta = 1 << 62;
  for (var i = 0; i < items.length; i++) {
    final d = (timestampMs(items[i]) - targetMs).abs();
    if (d < bestDelta) {
      bestDelta = d;
      best = i;
    }
  }
  return best;
}
