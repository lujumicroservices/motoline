import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/brake_detection.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/theme/ride_viz_palette.dart';

void main() {
  test('speedColor uses distinct hues across the ramp', () {
    final slow = RideVizPalette.speedColor(10);
    final mid = RideVizPalette.speedColor(100);
    final fast = RideVizPalette.speedColor(250);

    expect(slow.toARGB32(), isNot(mid.toARGB32()));
    expect(mid.toARGB32(), isNot(fast.toARGB32()));
    // Slow is blue-ish (more blue than red).
    expect(slow.b, greaterThan(slow.r));
    // Fast end is more red/magenta than blue.
    expect(fast.r + fast.b, greaterThan(fast.g));
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
}
