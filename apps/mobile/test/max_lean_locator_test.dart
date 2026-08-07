import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/lean_lab/max_lean_locator.dart';
import 'package:motoline/core/models/track_point.dart';

TrackPoint _pt(int i, {double? lean, double lat = 20.6, double lng = -103.45}) {
  return TrackPoint(
    id: null,
    rideId: 'r',
    latitude: lat + i * 0.00001,
    longitude: lng + i * 0.00001,
    timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
    leanDegrees: lean,
    speedMps: 15,
  );
}

void main() {
  test('findMaxLeanInWindow picks peak abs lean and GPS span', () {
    final samples = [
      _pt(0, lean: 0),
      _pt(1, lean: -10),
      _pt(2, lean: -28),
      _pt(3, lean: -35), // peak
      _pt(4, lean: -33),
      _pt(5, lean: -12),
      _pt(6, lean: 0),
    ];
    final hit = findMaxLeanInWindow(
      samples: samples,
      lo: 0,
      hi: samples.length - 1,
      neutralLeanDegrees: 0,
    );
    expect(hit, isNotNull);
    expect(hit!.peakIndex, 3);
    expect(hit.signedLeanDeg, closeTo(-35, 0.01));
    expect(hit.side, 'left');
    expect(hit.fromIndex, lessThanOrEqualTo(3));
    expect(hit.toIndex, greaterThanOrEqualTo(3));
    expect(hit.fromPoint.latitude, isNot(equals(hit.toPoint.latitude)));
  });
}
