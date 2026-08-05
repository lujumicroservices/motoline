import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/track_segment_align.dart';
import 'package:motoline/core/models/track_point.dart';

TrackPoint _pt(
  double lat,
  double lng, {
  required int i,
  String rideId = 'r',
}) {
  return TrackPoint(
    id: null,
    rideId: rideId,
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
    speedMps: 20,
    leanDegrees: i.isEven ? -12 : 8,
  );
}

List<TrackPoint> _lineEast({
  required double startLat,
  required double startLng,
  required int steps,
  double stepLng = 0.00012,
  String rideId = 'a',
}) {
  return [
    for (var i = 0; i < steps; i++)
      _pt(startLat, startLng + i * stepLng, i: i, rideId: rideId),
  ];
}

void main() {
  test('alignCornerToPeer crops both to the same shared stretch', () {
    final local = _lineEast(startLat: 20.7, startLng: -103.4, steps: 100);
    // Peer covers only mid section with a tiny offset inside corridor.
    final peer = _lineEast(
      startLat: 20.70005,
      startLng: -103.4 + 25 * 0.00012,
      steps: 50,
      rideId: 'b',
    );

    final aligned = alignCornerToPeer(
      localSamples: local,
      mapStartIndex: 20,
      mapEndIndex: 80,
      peerSamples: peer,
    );

    expect(aligned, isNotNull);
    expect(aligned!.isUsable, isTrue);
    expect(aligned.left.length, greaterThanOrEqualTo(2));
    expect(aligned.right.length, greaterThanOrEqualTo(2));
    expect(aligned.sharedMeters, greaterThan(40));
  });

  test('alignSharedCorridor returns null for distant tracks', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 80);
    final b = _lineEast(
      startLat: 21.0,
      startLng: -103.4,
      steps: 80,
      rideId: 'b',
    );
    expect(alignSharedCorridor(a, b), isNull);
  });

  test('indexAtPathFraction hits ends', () {
    final pts = _lineEast(startLat: 20.7, startLng: -103.4, steps: 40);
    expect(indexAtPathFraction(pts, 0), 0);
    expect(indexAtPathFraction(pts, 1), pts.length - 1);
    final mid = indexAtPathFraction(pts, 0.5);
    expect(mid, greaterThan(5));
    expect(mid, lessThan(pts.length - 5));
  });
}
