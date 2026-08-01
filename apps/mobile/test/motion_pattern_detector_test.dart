import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/motion_pattern_detector.dart';

void main() {
  group('auto-pause / resume', () {
    test('pauses after sustained slow speed', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      // Below pause threshold (8 km/h ~ 2.2 m/s) for < pauseAfter (12s): not yet paused.
      for (var t = 0; t <= 10; t += 2) {
        detector.feedRideSample(
          speedMps: 1.0,
          latitude: 10,
          longitude: 10,
          timestamp: base.add(Duration(seconds: t)),
        );
      }
      expect(detector.isPaused, isFalse);

      // Continue past the 12s threshold.
      detector.feedRideSample(
        speedMps: 1.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 13)),
      );
      expect(detector.isPaused, isTrue);
    });

    test('does not pause if speed recovers before threshold', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 1.0,
        latitude: 10,
        longitude: 10,
        timestamp: base,
      );
      detector.feedRideSample(
        speedMps: 1.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 5)),
      );
      // Speed recovers above pause threshold before 12s elapsed.
      detector.feedRideSample(
        speedMps: 5.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 8)),
      );
      detector.feedRideSample(
        speedMps: 1.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 19)),
      );
      expect(detector.isPaused, isFalse);
    });

    test('resumes when speed exceeds resume threshold for resumeAfter', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base,
      );
      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 13)),
      );
      expect(detector.isPaused, isTrue);

      // Sustained fast speed (>12 km/h ~ 3.33 m/s) for >= 3s resumes.
      detector.feedRideSample(
        speedMps: 4.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 14)),
      );
      expect(detector.isPaused, isTrue); // not yet sustained long enough

      detector.feedRideSample(
        speedMps: 4.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 18)),
      );
      expect(detector.isPaused, isFalse);
    });

    test('resumes on meaningful movement even without sustained speed', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base,
      );
      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 13)),
      );
      expect(detector.isPaused, isTrue);

      // Move ~20m away (walking the bike out of a driveway) without high speed.
      detector.feedRideSample(
        speedMps: null,
        latitude: 10.0002,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 20)),
      );
      expect(detector.isPaused, isFalse);
    });
  });

  group('suggest end', () {
    test('sets suggestEnd after long near-stationary window', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 20,
        longitude: 20,
        timestamp: base,
      );
      expect(detector.suggestEnd, isFalse);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 20,
        longitude: 20,
        timestamp: base.add(const Duration(minutes: 5)),
      );
      expect(detector.suggestEnd, isFalse);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 20,
        longitude: 20,
        timestamp: base.add(const Duration(minutes: 11)),
      );
      expect(detector.suggestEnd, isTrue);
    });

    test('clears suggestEnd once motion resumes', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 20,
        longitude: 20,
        timestamp: base,
      );
      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 20,
        longitude: 20,
        timestamp: base.add(const Duration(minutes: 11)),
      );
      expect(detector.suggestEnd, isTrue);

      detector.feedRideSample(
        speedMps: 10.0,
        latitude: 20,
        longitude: 20,
        timestamp: base.add(const Duration(minutes: 11, seconds: 5)),
      );
      expect(detector.suggestEnd, isFalse);
    });
  });

  group('arm -> auto-start', () {
    test('does not trigger before speed or distance thresholds', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      var triggered = detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30,
        longitude: 30,
        timestamp: base,
      );
      expect(triggered, isFalse);

      // Fast but only a few seconds — not sustained yet, tiny distance.
      triggered = detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30.0002,
        longitude: 30,
        timestamp: base.add(const Duration(seconds: 3)),
      );
      expect(triggered, isFalse);
    });

    test('triggers once speed is sustained (distance optional)', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30.0000,
        longitude: 30,
        timestamp: base,
      );
      detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30.0002,
        longitude: 30,
        timestamp: base.add(const Duration(seconds: 4)),
      );
      final triggered = detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30.0004,
        longitude: 30,
        timestamp: base.add(const Duration(seconds: 9)),
      );
      expect(triggered, isTrue);
    });

    test('triggers once distance covered (speed optional)', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      // Slow crawl but >80m cumulative (~0.001 deg lat ≈ 111m).
      detector.feedArmedSample(
        speedMps: 1.0,
        latitude: 30.0000,
        longitude: 30,
        timestamp: base,
      );
      final triggered = detector.feedArmedSample(
        speedMps: 1.0,
        latitude: 30.0010,
        longitude: 30,
        timestamp: base.add(const Duration(seconds: 2)),
      );
      expect(triggered, isTrue);
    });

    test('resetArm clears cumulative distance and speed timer', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30,
        longitude: 30,
        timestamp: base,
      );
      detector.resetArm();

      final triggered = detector.feedArmedSample(
        speedMps: 8.0,
        latitude: 30.0020,
        longitude: 30,
        timestamp: base.add(const Duration(seconds: 9)),
      );
      // Immediately after reset there's no prior point to accumulate
      // distance from, and a single sample cannot sustain 8s yet.
      expect(triggered, isFalse);
    });
    test('skips pause when autoPauseEnabled is false', () {
      final detector = MotionPatternDetector()..autoPauseEnabled = false;
      final base = DateTime(2026, 1, 1);

      for (var t = 0; t <= 20; t += 2) {
        detector.feedRideSample(
          speedMps: 0.0,
          latitude: 10,
          longitude: 10,
          timestamp: base.add(Duration(seconds: t)),
        );
      }
      expect(detector.isPaused, isFalse);
    });

    test('clearPause resumes when disabling mid-pause', () {
      final detector = MotionPatternDetector();
      final base = DateTime(2026, 1, 1);

      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base,
      );
      detector.feedRideSample(
        speedMps: 0.0,
        latitude: 10,
        longitude: 10,
        timestamp: base.add(const Duration(seconds: 13)),
      );
      expect(detector.isPaused, isTrue);

      detector.autoPauseEnabled = false;
      detector.clearPause();
      expect(detector.isPaused, isFalse);
    });
  });
}
