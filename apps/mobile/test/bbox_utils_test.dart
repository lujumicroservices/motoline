import 'package:flutter_test/flutter_test.dart';

import 'package:motoline/core/analytics/bbox_utils.dart';
import 'package:motoline/core/models/track_point.dart';

void main() {
  TrackPoint p(double lat, double lng) => TrackPoint(
        id: null,
        rideId: 't',
        latitude: lat,
        longitude: lng,
        timestamp: DateTime(2026),
      );

  test('bboxFromPoints and overlap with pad', () {
    final a = bboxFromPoints([p(19.0, -99.0), p(19.01, -98.99)])!;
    final nearby = bboxFromPoints([p(19.005, -98.995), p(19.008, -98.992)])!;
    final far = bboxFromPoints([p(40.0, -74.0), p(40.01, -73.99)])!;

    expect(a.overlapsSimilar(nearby), isTrue);
    expect(a.overlapsSimilar(far), isFalse);
  });
}
