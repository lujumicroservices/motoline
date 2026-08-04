import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/track_overlap.dart';
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
  );
}

/// Roughly eastward line: ~111 m per 0.001° lon at equator-ish mid lat.
List<TrackPoint> _lineEast({
  required double startLat,
  required double startLng,
  required int steps,
  double stepLng = 0.00012, // ~13 m
  String rideId = 'a',
}) {
  return [
    for (var i = 0; i < steps; i++)
      _pt(startLat, startLng + i * stepLng, i: i, rideId: rideId),
  ];
}

void main() {
  const matcher = TrackOverlapMatcher();

  test('identical path is near 100% match', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 80);
    final b = List<TrackPoint>.from(a);
    final r = matcher.compute(a, b);
    expect(r.matchPctA, greaterThan(0.85));
    expect(r.matchPctB, greaterThan(0.85));
    expect(r.sharedMeters, greaterThan(500));
    expect(r.runs, isNotEmpty);
  });

  test('parallel offset beyond corridor does not match', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 80);
    // ~90 m north — outside 40 m corridor.
    final b = _lineEast(
      startLat: 20.7 + 0.00085,
      startLng: -103.4,
      steps: 80,
      rideId: 'b',
    );
    final r = matcher.compute(a, b);
    expect(r.matchPctA, lessThan(0.1));
    expect(r.sharedMeters, lessThan(80));
  });

  test('partial shared middle reports expected percent range', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 100);
    // Peer only covers middle ~40% of A.
    final b = a.sublist(30, 70);
    final r = matcher.compute(a, b);
    expect(r.matchPctA, greaterThan(0.25));
    expect(r.matchPctA, lessThan(0.55));
    expect(r.matchPctB, greaterThan(0.7));
  });

  test('opposite direction does not count as match', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 80);
    final b = a.reversed.toList();
    // Re-stamp timestamps ascending so duration is sane.
    final rev = [
      for (var i = 0; i < b.length; i++)
        TrackPoint(
          id: null,
          rideId: 'b',
          latitude: b[i].latitude,
          longitude: b[i].longitude,
          timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
        ),
    ];
    final r = matcher.compute(a, rev);
    expect(r.matchPctA, lessThan(0.2));
  });

  test('meetsMinMatch uses shared meters or percent', () {
    final a = _lineEast(startLat: 20.7, startLng: -103.4, steps: 80);
    final b = List<TrackPoint>.from(a);
    final r = matcher.compute(a, b);
    expect(r.meetsMinMatch(), isTrue);
    expect(TrackOverlapResult.empty.meetsMinMatch(), isFalse);
  });
}
