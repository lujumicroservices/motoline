import 'package:ride_core/ride_core.dart';
import 'package:test/test.dart';

void main() {
  group('gps gaps', () {
    test('detects time gaps', () {
      final t0 = DateTime.utc(2026, 1, 1, 12);
      final stamps = [
        t0,
        t0.add(const Duration(seconds: 1)),
        t0.add(const Duration(seconds: 20)),
        t0.add(const Duration(seconds: 21)),
      ];
      expect(gpsGapStartIndices(stamps), [2]);
    });

    test('splitTrackByGaps', () {
      final t0 = DateTime.utc(2026, 1, 1);
      final points = [
        (t0, 'a'),
        (t0.add(const Duration(seconds: 1)), 'b'),
        (t0.add(const Duration(seconds: 30)), 'c'),
      ];
      final segs = splitTrackByGaps(points, (p) => p.$1);
      expect(segs.length, 2);
      expect(segs[0].map((e) => e.$2).toList(), ['a', 'b']);
      expect(segs[1].map((e) => e.$2).toList(), ['c']);
    });
  });

  group('smoothness', () {
    test('steady speeds score high', () {
      final score = smoothnessScoreFromSpeeds(
        List.filled(20, 15.0),
      );
      expect(score, greaterThan(90));
    });

    test('jerky speeds score lower', () {
      final jerky = <double?>[
        for (var i = 0; i < 20; i++) (i.isEven ? 5.0 : 25.0),
      ];
      final score = smoothnessScoreFromSpeeds(jerky);
      expect(score, lessThan(50));
    });
  });

  group('outbox backoff', () {
    test('grows then caps', () {
      final t0 = 1_000_000;
      final a0 = SyncOutboxItem.nextAttemptMs(attempts: 0, nowMs: t0);
      final a3 = SyncOutboxItem.nextAttemptMs(attempts: 3, nowMs: t0);
      final a9 = SyncOutboxItem.nextAttemptMs(attempts: 9, nowMs: t0);
      expect(a0 - t0, 30 * 1000);
      expect(a3 - t0, greaterThan(a0 - t0));
      expect(a9 - t0, 1800 * 1000);
    });
  });
}
