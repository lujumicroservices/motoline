import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/ride_analytics.dart';
import 'package:motoline/core/analytics/track_lod.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/core/models/track_point.dart';

TrackPoint _pt(int i, {required int ts}) {
  return TrackPoint(
    id: i,
    rideId: 'r1',
    latitude: 21.0 + i * 0.001,
    longitude: -103.0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
  );
}

void main() {
  test('overviewIndices always includes first and last', () {
    final idx = overviewIndices(5450, 1000);
    expect(idx.first, 0);
    expect(idx.last, 5449);
    expect(idx.length, lessThanOrEqualTo(1002));
    expect(idx.length, greaterThan(900));
  });

  test('overviewIndices returns all when short', () {
    expect(overviewIndices(10, 1000), [for (var i = 0; i < 10; i++) i]);
  });

  test('filterTimeWindow is inclusive', () {
    final items = [10, 20, 30, 40, 50];
    expect(filterTimeWindow(items, (n) => n, 20, 40), [20, 30, 40]);
  });

  test('scrub overview index maps to window by timestamp', () {
    final full = [for (var i = 0; i < 100; i++) _pt(i, ts: 1_000_000 + i * 1000)];
    final overview = pickOverview(full, 10);
    expect(overview.first.id, 0);
    expect(overview.last.id, 99);

    final ovIdx = 3;
    final ts = overview[ovIdx].timestamp.millisecondsSinceEpoch;
    final window = filterTimeWindow(
      full,
      (p) => p.timestamp.millisecondsSinceEpoch,
      ts - 3000,
      ts + 3000,
    );
    final nearest = nearestIndexByTime(
      window,
      (p) => p.timestamp.millisecondsSinceEpoch,
      ts,
    );
    expect(window[nearest].timestamp.millisecondsSinceEpoch, ts);
  });

  test('nearestIndexByTime binary search matches linear on a long series', () {
    final items = [for (var i = 0; i < 2000; i++) 1_000_000 + i * 250];
    int linear(int target) {
      var best = 0;
      var bestDelta = 1 << 62;
      for (var i = 0; i < items.length; i++) {
        final d = (items[i] - target).abs();
        if (d < bestDelta) {
          bestDelta = d;
          best = i;
        }
      }
      return best;
    }

    for (final target in [1_000_000, 1_000_100, 1_250_000, 1_499_875, 2_000_000]) {
      expect(
        nearestIndexByTime(items, (n) => n, target),
        linear(target),
      );
    }
  });

  test('overview analytics keeps stored ride distance', () {
    final ride = Ride(
      id: 'r1',
      startedAt: DateTime.utc(2026, 8, 20, 22, 9),
      endedAt: DateTime.utc(2026, 8, 20, 23, 51),
      status: RideStatus.completed,
      distanceMeters: 120580,
      pointCount: 5450,
    );
    final points = [
      _pt(0, ts: 1),
      _pt(1, ts: 2),
      _pt(2, ts: 3),
    ];
    final a = RideAnalytics(
      ride: ride,
      points: points,
      computeLab: false,
    );
    expect(a.distanceKm, closeTo(120.58, 0.01));
    expect(a.roadStretches, isEmpty);
    expect(a.curveEvents, isEmpty);
  });
}
