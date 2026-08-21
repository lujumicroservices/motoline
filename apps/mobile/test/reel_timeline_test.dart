import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/reel/reel_timeline.dart';

void main() {
  test('fromLength totals match each preset exactly', () {
    for (final length in ReelLength.values) {
      for (var n = 0; n <= length.maxPauseChapters; n++) {
        final timeline = ReelTimeline.fromLength(length, pauseCount: n);
        expect(timeline.totalSec, length.totalSec);
        final sum = timeline.scenes.fold<double>(
          0,
          (acc, scene) => acc + scene.durationSec,
        );
        expect(sum, closeTo(length.totalSec, 1e-9));
        expect(timeline.scenes.last.endSec, length.totalSec);
      }
    }
  });

  test('unused pause chapters are absorbed by the trail', () {
    const length = ReelLength.standard;
    final full = ReelTimeline.fromLength(length, pauseCount: 3);
    final one = ReelTimeline.fromLength(length, pauseCount: 1);

    expect(one.totalSec, full.totalSec);
    expect(one.hookDuration, full.hookDuration);
    expect(one.statsDuration, full.statsDuration);
    expect(one.endDuration, full.endDuration);
    expect(one.photosDuration, length.chapterSec);
    expect(
      one.trailDuration,
      closeTo(full.trailDuration + 2 * length.chapterSec, 1e-9),
    );
  });

  test('zero pauses puts the full chapter budget on the trail', () {
    const length = ReelLength.short;
    final empty = ReelTimeline.fromLength(length, pauseCount: 0);
    final full = ReelTimeline.fromLength(
      length,
      pauseCount: length.maxPauseChapters,
    );

    expect(empty.photosDuration, 0);
    expect(
      empty.trailDuration,
      closeTo(
        full.trailDuration + length.maxPauseChapters * length.chapterSec,
        1e-9,
      ),
    );
  });

  test('maxPauseChapters and maxPhotos match the presets', () {
    expect(ReelLength.short.totalSec, 15);
    expect(ReelLength.short.maxPauseChapters, 2);
    expect(ReelLength.short.maxPhotos, 4);

    expect(ReelLength.standard.totalSec, 20);
    expect(ReelLength.standard.maxPauseChapters, 3);
    expect(ReelLength.standard.maxPhotos, 6);

    expect(ReelLength.long.totalSec, 30);
    expect(ReelLength.long.maxPauseChapters, 4);
    expect(ReelLength.long.maxPhotos, 8);
  });

  test('pauseCount above the cap is clamped', () {
    final timeline = ReelTimeline.fromLength(
      ReelLength.short,
      pauseCount: 99,
    );
    expect(
      timeline.photosDuration,
      closeTo(
        ReelLength.short.maxPauseChapters * ReelLength.short.chapterSec,
        1e-9,
      ),
    );
  });

  test('real pause counts do not reserve unused chapters', () {
    const length = ReelLength.long;
    final none = ReelTimeline.fromLength(length, pauseCount: 0);
    final two = ReelTimeline.fromLength(length, pauseCount: 2);
    expect(none.photosDuration, 0);
    expect(two.photosDuration, closeTo(2 * length.chapterSec, 1e-9));
    expect(none.totalSec, length.totalSec);
    expect(two.totalSec, length.totalSec);
  });

  test('capPauses and capPhotos truncate to the preset', () {
    const length = ReelLength.short;
    expect(length.capPauses([1, 2, 3, 4]), [1, 2]);
    expect(length.capPhotos([1, 2, 3, 4, 5]), [1, 2, 3, 4]);
    expect(length.clampPauseCount(8), 2);
    expect(length.clampPhotoCount(9), 4);
  });
}
