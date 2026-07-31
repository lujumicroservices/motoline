import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/features/ride_detail/map_polyline_builder.dart';

void main() {
  TrackPoint p(int i, {required double speedKmh}) {
    return TrackPoint(
      id: i,
      rideId: 'r',
      latitude: 25.0 + i * 0.0001,
      longitude: -100.0,
      timestamp: DateTime.utc(2026, 7, 30).add(Duration(seconds: i)),
      speedMps: speedKmh / 3.6,
    );
  }

  List<(RoadKind, TurnSide)?> emptyKinds(int n) =>
      List<(RoadKind, TurnSide)?>.filled(n, null);

  test('buildMergedStyledPolylines merges same-speed edges', () {
    final points = [
      for (var i = 0; i < 40; i++) p(i, speedKmh: 60),
    ];

    final polylines = buildMergedStyledPolylines(
      segment: points,
      indexOffset: 0,
      kindByIndex: emptyKinds(points.length),
      showRoadKindContrast: false,
      showSpeedColors: true,
    );

    // One steady speed → far fewer than N-1 edge polylines.
    expect(polylines.length, lessThan(5));
    expect(polylines.first.points.length, greaterThan(10));
  });

  test('buildMergedStyledPolylines splits when speed bucket changes', () {
    final points = <TrackPoint>[
      for (var i = 0; i < 10; i++) p(i, speedKmh: 40),
      for (var i = 10; i < 20; i++) p(i, speedKmh: 100),
    ];

    final polylines = buildMergedStyledPolylines(
      segment: points,
      indexOffset: 0,
      kindByIndex: emptyKinds(points.length),
      showRoadKindContrast: false,
      showSpeedColors: true,
    );

    expect(polylines.length, greaterThanOrEqualTo(2));
    expect(
      polylines.fold<int>(0, (n, pl) => n + pl.points.length - 1),
      points.length - 1,
    );
  });

  test('empty or single point yields no polylines', () {
    expect(
      buildMergedStyledPolylines(
        segment: const [],
        indexOffset: 0,
        kindByIndex: const [],
        showRoadKindContrast: false,
        showSpeedColors: true,
      ),
      isEmpty,
    );
    expect(
      buildMergedStyledPolylines(
        segment: [p(0, speedKmh: 50)],
        indexOffset: 0,
        kindByIndex: emptyKinds(1),
        showRoadKindContrast: false,
        showSpeedColors: true,
      ),
      isEmpty,
    );
  });
}
