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

  test('segmentIndicesInBounds returns null when too few points', () {
    final points = [p(0.01, 0.01, 0)];
    final hit = segmentIndicesInBounds(
      points: points,
      isInside: (_) => true,
    );
    expect(hit, isNull);
  });
}
