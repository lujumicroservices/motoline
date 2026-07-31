import 'package:flutter_test/flutter_test.dart';

import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/utils/geo_utils.dart';

void main() {
  TrackPoint p(double lat, double lon, int i) => TrackPoint(
        id: i,
        rideId: 'r',
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
      );

  test('segmentIndicesInBounds picks longest contiguous run', () {
    final points = [
      p(0, 0, 0),
      p(0.01, 0.01, 1), // inside
      p(0.02, 0.02, 2), // inside
      p(1, 1, 3), // outside
      p(0.015, 0.015, 4), // inside alone
    ];

    final hit = segmentIndicesInBounds(
      points: points,
      isInside: (pt) =>
          pt.latitude >= 0.005 &&
          pt.latitude <= 0.025 &&
          pt.longitude >= 0.005 &&
          pt.longitude <= 0.025,
    );

    expect(hit, isNotNull);
    expect(hit!.start, 1);
    expect(hit.end, 2);
    expect(hit.insideCount, 3);
  });

  test('segmentIndicesInBounds bridges short GPS outliers', () {
    final close = [
      p(0.01050, 0.01050, 0),
      p(0.01060, 0.01055, 1),
      p(0.01102, 0.01058, 2), // just outside, short hop
      p(0.01070, 0.01065, 3),
      p(0.01080, 0.01070, 4),
    ];
    final hit = segmentIndicesInBounds(
      points: close,
      isInside: (pt) =>
          pt.latitude >= 0.0104 &&
          pt.latitude <= 0.0110 &&
          pt.longitude >= 0.0104 &&
          pt.longitude <= 0.0110,
      maxBridgeOutside: 2,
    );

    expect(hit, isNotNull);
    expect(hit!.start, 0);
    expect(hit.end, 4);
  });

  test('segmentIndicesInBounds prefers run near box center', () {
    // Two equal-length passes; prefer the one near preferLat/Lng.
    final points = [
      p(0.01, 0.01, 0),
      p(0.012, 0.012, 1),
      p(0.014, 0.014, 2),
      p(5, 5, 3),
      p(0.11, 0.11, 4),
      p(0.112, 0.112, 5),
      p(0.114, 0.114, 6),
    ];

    final hit = segmentIndicesInBounds(
      points: points,
      isInside: (pt) =>
          (pt.latitude >= 0.005 &&
              pt.latitude <= 0.025 &&
              pt.longitude >= 0.005 &&
              pt.longitude <= 0.025) ||
          (pt.latitude >= 0.105 &&
              pt.latitude <= 0.125 &&
              pt.longitude >= 0.105 &&
              pt.longitude <= 0.125),
      preferLat: 0.112,
      preferLng: 0.112,
    );

    expect(hit, isNotNull);
    expect(hit!.start, 4);
    expect(hit.end, 6);
  });

  test('segmentIndicesInBounds returns null when too few points', () {
    final points = [p(0.01, 0.01, 0)];
    final hit = segmentIndicesInBounds(
      points: points,
      isInside: (_) => true,
    );
    expect(hit, isNull);
  });
}
