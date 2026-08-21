enum ReelLength {
  short,
  standard,
  long;

  double get totalSec => switch (this) {
        ReelLength.short => 15,
        ReelLength.standard => 20,
        ReelLength.long => 30,
      };

  int get durationMs => (totalSec * 1000).round();

  int get maxPauseChapters => switch (this) {
        ReelLength.short => 2,
        ReelLength.standard => 3,
        ReelLength.long => 4,
      };

  int get maxPhotos => switch (this) {
        ReelLength.short => 4,
        ReelLength.standard => 6,
        ReelLength.long => 8,
      };

  double get hookSec => switch (this) {
        ReelLength.short => 1.2,
        ReelLength.standard => 1.5,
        ReelLength.long => 1.5,
      };

  double get statsSec => switch (this) {
        ReelLength.short => 2.5,
        ReelLength.standard => 3.5,
        ReelLength.long => 4.0,
      };

  double get endSec => switch (this) {
        ReelLength.short => 2.2,
        ReelLength.standard => 3.0,
        ReelLength.long => 3.5,
      };

  double get chapterSec => switch (this) {
        ReelLength.short => 1.8,
        ReelLength.standard => 2.0,
        ReelLength.long => 2.5,
      };

  int clampPauseCount(int count) => count.clamp(0, maxPauseChapters);

  int clampPhotoCount(int count) => count.clamp(0, maxPhotos);

  /// Keeps the first [maxPauseChapters] items (already ranked by the caller).
  List<T> capPauses<T>(List<T> pauses) {
    if (pauses.length <= maxPauseChapters) return pauses;
    return pauses.sublist(0, maxPauseChapters);
  }

  /// Keeps the first [maxPhotos] items selected for the video.
  List<T> capPhotos<T>(List<T> photos) {
    if (photos.length <= maxPhotos) return photos;
    return photos.sublist(0, maxPhotos);
  }

  static ReelLength fromName(String? name) {
    for (final value in ReelLength.values) {
      if (value.name == name) return value;
    }
    return ReelLength.standard;
  }
}

class ReelScene {
  const ReelScene({
    required this.kind,
    required this.startSec,
    required this.endSec,
  });

  final ReelSceneKind kind;
  final double startSec;
  final double endSec;

  double get durationSec => endSec - startSec;

  double localT(double timeSec) {
    if (durationSec <= 0) return 1;
    return ((timeSec - startSec) / durationSec).clamp(0.0, 1.0);
  }
}

enum ReelSceneKind { hook, trail, photos, stats, endCard }

class ReelTimeline {
  ReelTimeline({
    this.hookEnd = 1.5,
    this.trailEnd = 7.5,
    this.photosEnd = 13.5,
    this.statsEnd = 17.0,
    this.totalSec = 20.0,
  });

  /// Builds a timeline for [length]. Unused pause-chapter time is added to
  /// the trail so [totalSec] stays exact.
  factory ReelTimeline.fromLength(
    ReelLength length, {
    int pauseCount = 0,
  }) {
    final chapters = length.clampPauseCount(pauseCount);
    final hook = length.hookSec;
    final photos = chapters * length.chapterSec;
    final stats = length.statsSec;
    final end = length.endSec;
    final trail = length.totalSec - hook - photos - stats - end;
    return ReelTimeline(
      hookEnd: hook,
      trailEnd: hook + trail,
      photosEnd: hook + trail + photos,
      statsEnd: hook + trail + photos + stats,
      totalSec: length.totalSec,
    );
  }

  final double hookEnd;
  final double trailEnd;
  final double photosEnd;
  final double statsEnd;
  final double totalSec;

  double get hookDuration => hookEnd;
  double get trailDuration => trailEnd - hookEnd;
  double get photosDuration => photosEnd - trailEnd;
  double get statsDuration => statsEnd - photosEnd;
  double get endDuration => totalSec - statsEnd;

  late final List<ReelScene> scenes = [
    ReelScene(kind: ReelSceneKind.hook, startSec: 0, endSec: hookEnd),
    ReelScene(kind: ReelSceneKind.trail, startSec: hookEnd, endSec: trailEnd),
    ReelScene(kind: ReelSceneKind.photos, startSec: trailEnd, endSec: photosEnd),
    ReelScene(kind: ReelSceneKind.stats, startSec: photosEnd, endSec: statsEnd),
    ReelScene(kind: ReelSceneKind.endCard, startSec: statsEnd, endSec: totalSec),
  ];

  ReelScene sceneAt(double timeSec) {
    for (final s in scenes) {
      if (timeSec < s.endSec) return s;
    }
    return scenes.last;
  }
}

class ReelCopy {
  const ReelCopy({
    required this.leanLabel,
    required this.hookSub,
    required this.kmLabel,
    required this.curvesLabel,
    required this.ridersLabel,
    required this.speedLabel,
    required this.endQuestion,
    required this.cta,
  });

  final String leanLabel;
  final String hookSub;
  final String kmLabel;
  final String curvesLabel;
  final String ridersLabel;
  final String speedLabel;
  final String endQuestion;
  final String cta;
}
