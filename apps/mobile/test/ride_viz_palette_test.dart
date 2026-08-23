import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/brake_detection.dart';
import 'package:motoline/core/analytics/track_lod.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/theme/ride_viz_palette.dart';

void main() {
  test('speedColor uses distinct hues across the ramp', () {
    final slow = RideVizPalette.speedColor(10);
    final mid = RideVizPalette.speedColor(70);
    final fast = RideVizPalette.speedColor(200);

    expect(slow.toARGB32(), isNot(mid.toARGB32()));
    expect(mid.toARGB32(), isNot(fast.toARGB32()));
    // Slow is blue-ish (more blue than red).
    expect(slow.b, greaterThan(slow.r));
    // Street brisk (~65) already in warm yellow territory (R+G high).
    expect(mid.r + mid.g, greaterThan(mid.b));
    // Fast end is more red/magenta than blue.
    expect(fast.r + fast.b, greaterThan(fast.g));
  });

  test('warm colors arrive at street speeds', () {
    final city = RideVizPalette.speedColor(65);
    final highway = RideVizPalette.speedColor(90);
    // Yellow-ish at city brisk: more red+green than blue.
    expect(city.r, greaterThan(city.b));
    expect(city.g, greaterThan(city.b));
    // Orange at highway: red dominates green a bit more than at yellow.
    expect(highway.r, greaterThan(highway.g));
  });

  test('leanColor uses cyan left and amber right', () {
    expect(RideVizPalette.leanColor(-20), RideVizPalette.leanLeft);
    expect(RideVizPalette.leanColor(20), RideVizPalette.leanRight);
  });

  test('detectBrakeEvents finds a hard stop from speed drop', () {
    final t0 = DateTime.utc(2026, 7, 30, 18);
    // Cruise then hard brake: 20 m/s → 5 m/s over 1s ≈ 15 m/s²
    final points = <TrackPoint>[
      for (var i = 0; i < 5; i++)
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25,
          longitude: -100,
          timestamp: t0.add(Duration(milliseconds: i * 200)),
          speedMps: 20,
        ),
      for (var i = 0; i < 6; i++)
        TrackPoint(
          id: 10 + i,
          rideId: 'r',
          latitude: 25,
          longitude: -100,
          timestamp: t0.add(Duration(milliseconds: 1000 + i * 200)),
          speedMps: 20 - i * 3.0,
        ),
    ];

    final events = detectBrakeEvents(points);
    expect(events, isNotEmpty);
    expect(events.first.hardness, BrakeHardness.hard);
    expect(events.first.speedDropKmh, greaterThan(20));
  });

  test('remapBrakeEvents projects lab indices onto a downsampled map', () {
    final t0 = DateTime.utc(2026, 8, 22, 12);
    // Dense 1 Hz cruise with a hard stop around sample 1500.
    final full = <TrackPoint>[
      for (var i = 0; i < 2000; i++)
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: 25 + i * 0.00001,
          longitude: -100,
          timestamp: t0.add(Duration(seconds: i)),
          speedMps: i >= 1495 && i <= 1505 ? 20 - (i - 1495) * 1.8 : 20,
        ),
    ];
    final events = detectBrakeEvents(full);
    expect(events, isNotEmpty);
    expect(events.first.endIndex, greaterThan(1000));

    final overview = pickOverview(full, 200);
    expect(overview.length, lessThan(full.length));
    expect(events.first.endIndex, greaterThanOrEqualTo(overview.length));

    final mapped = remapBrakeEvents(
      events: events,
      source: full,
      target: overview,
    );
    expect(mapped, hasLength(events.length));
    final mid = ((mapped.first.startIndex + mapped.first.endIndex) / 2)
        .round();
    expect(mid, inInclusiveRange(0, overview.length - 1));
    final mappedAt = overview[mid].timestamp;
    final sourceMid =
        ((events.first.startIndex + events.first.endIndex) / 2).round();
    final delta = mappedAt.difference(full[sourceMid].timestamp).abs();
    expect(delta.inSeconds, lessThan(20));
  });
}
