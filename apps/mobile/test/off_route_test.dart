import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:motoline/core/routing/off_route.dart';

void main() {
  test('distance to a collinear point on the segment is near zero', () {
    const a = LatLng(20.67, -103.35);
    const b = LatLng(20.68, -103.35);
    const mid = LatLng(20.675, -103.35);
    expect(distancePointToSegmentMeters(mid, a, b), lessThan(2));
    expect(distanceToPolylineMeters(mid, const [a, b]), lessThan(2));
  });

  test('point ~100 m east of a meridian is measured near 100 m', () {
    const a = LatLng(20.67, -103.35);
    const b = LatLng(20.68, -103.35);
    // 0.001 deg lng ≈ 104 m at this latitude.
    const east = LatLng(20.675, -103.349);
    final d = distancePointToSegmentMeters(east, a, b);
    expect(d, greaterThan(90));
    expect(d, lessThan(120));
  });

  test('off-route needs 15s outside corridor then clears when back', () {
    final tracker = OffRouteTracker(
      thresholdM: 100,
      hold: const Duration(seconds: 15),
    );
    final t0 = DateTime.utc(2026, 8, 21, 12);
    expect(tracker.update(distanceM: 150, now: t0), isFalse);
    expect(
      tracker.update(distanceM: 150, now: t0.add(const Duration(seconds: 14))),
      isFalse,
    );
    expect(
      tracker.update(distanceM: 150, now: t0.add(const Duration(seconds: 15))),
      isTrue,
    );
    expect(
      tracker.update(distanceM: 40, now: t0.add(const Duration(seconds: 16))),
      isFalse,
    );
  });

  test('brief GPS spike under hold does not flag off-route', () {
    final tracker = OffRouteTracker(
      thresholdM: 100,
      hold: const Duration(seconds: 15),
    );
    final t0 = DateTime.utc(2026, 8, 21, 12);
    expect(tracker.update(distanceM: 200, now: t0), isFalse);
    expect(
      tracker.update(distanceM: 20, now: t0.add(const Duration(seconds: 5))),
      isFalse,
    );
  });
}
