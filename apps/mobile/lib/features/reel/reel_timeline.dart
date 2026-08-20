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
    this.trailEnd = 8.0,
    this.photosEnd = 13.0,
    this.statsEnd = 17.0,
    this.totalSec = 20.0,
  });

  final double hookEnd;
  final double trailEnd;
  final double photosEnd;
  final double statsEnd;
  final double totalSec;

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
