import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/brake_detection.dart';
import 'package:motoline/core/analytics/brake_list.dart';
import 'package:motoline/theme/ride_viz_palette.dart';

BrakeEvent _event({
  required int start,
  required int end,
  required double peak,
}) {
  return BrakeEvent(
    startIndex: start,
    endIndex: end,
    peakDecelMps2: peak,
    avgDecelMps2: peak,
    speedDropKmh: 20,
    startSpeedKmh: 80,
    endSpeedKmh: 60,
    duration: const Duration(seconds: 1),
    hardness: peak >= 5
        ? BrakeHardness.hard
        : peak >= 3
            ? BrakeHardness.medium
            : BrakeHardness.light,
  );
}

void main() {
  final events = [
    _event(start: 10, end: 12, peak: 1.6),
    _event(start: 40, end: 45, peak: 6.2),
    _event(start: 80, end: 84, peak: 3.4),
    _event(start: 120, end: 122, peak: 2.0),
    _event(start: 200, end: 206, peak: 7.1),
  ];

  test('overview ranks strongest first and caps', () {
    final slice = visibleBrakeEvents(
      events,
      cap: 3,
      sort: BrakeListSort.strongestFirst,
    );
    expect(slice.events.map((e) => e.peakDecelMps2), [7.1, 6.2, 3.4]);
    expect(slice.hiddenCount, 2);
  });

  test('free preview of 3 is the hardest three', () {
    final slice = visibleBrakeEvents(
      events,
      cap: overviewBrakeListCap,
      sort: BrakeListSort.strongestFirst,
    );
    expect(slice.events.first.peakDecelMps2, 7.1);
    final free = slice.events.take(3).toList();
    expect(free.map((e) => e.peakDecelMps2), [7.1, 6.2, 3.4]);
  });

  test('zoomed window is chronological when under cap', () {
    final slice = visibleBrakeEvents(
      events,
      cap: zoomedBrakeListCap,
      sort: BrakeListSort.chronological,
      secondsForIndex: (i) => i.toDouble(),
      windowStartSeconds: 30,
      windowEndSeconds: 90,
    );
    expect(slice.events.map((e) => e.startIndex), [40, 80]);
    expect(slice.hiddenCount, 0);
  });

  test('huge window keeps strongest then shows them in order', () {
    final many = [
      for (var i = 0; i < 30; i++)
        _event(start: i * 10, end: i * 10 + 2, peak: 1.5 + i * 0.1),
    ];
    final slice = visibleBrakeEvents(
      many,
      cap: zoomedBrakeListCap,
      sort: BrakeListSort.chronological,
      secondsForIndex: (i) => i.toDouble(),
      windowStartSeconds: 0,
      windowEndSeconds: 400,
    );
    expect(slice.events, hasLength(20));
    expect(slice.hiddenCount, 10);
    for (var i = 1; i < slice.events.length; i++) {
      expect(
        slice.events[i].startIndex,
        greaterThan(slice.events[i - 1].startIndex),
      );
    }
    expect(
      slice.events.map((e) => e.peakDecelMps2).reduce((a, b) => a < b ? a : b),
      greaterThan(many.first.peakDecelMps2),
    );
  });

  test('brakeOverlapsSeconds includes events that span the window', () {
    expect(
      brakeOverlapsSeconds(
        startSeconds: 8,
        endSeconds: 14,
        windowStart: 10,
        windowEnd: 12,
      ),
      isTrue,
    );
    expect(
      brakeOverlapsSeconds(
        startSeconds: 1,
        endSeconds: 2,
        windowStart: 10,
        windowEnd: 12,
      ),
      isFalse,
    );
  });
}
