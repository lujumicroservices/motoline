import '../models/track_point.dart';
import 'curva_analysis.dart';
import 'road_kind_detection.dart';

/// Per-corner skill rating derived from GPS + lean (no extra hardware).
class CornerSkill {
  const CornerSkill({
    required this.analysis,
    required this.score,
    required this.tips,
    required this.fingerprint,
  });

  final CurvaAnalysis analysis;
  final int score;
  final List<String> tips;
  final String fingerprint;

  String get label => analysis.labelEs;
}

class RideSkillSummary {
  const RideSkillSummary({
    required this.corners,
    required this.sessionScore,
    required this.highlights,
    required this.focusTips,
  });

  final List<CornerSkill> corners;
  final int sessionScore;
  final List<String> highlights;
  final List<String> focusTips;

  int get curvaCount => corners.length;
}

/// Rate corners and produce short coach insights for the rider.
class CornerSkillEngine {
  const CornerSkillEngine();

  RideSkillSummary evaluate({
    required List<TrackPoint> samples,
    required List<RoadStretch> stretches,
    required double neutralLeanDegrees,
  }) {
    final corners = <CornerSkill>[];
    for (final s in stretches) {
      if (s.kind != RoadKind.curva) continue;
      final analysis = CurvaAnalysis.fromRide(
        samples: samples,
        stretch: s,
        neutralLeanDegrees: neutralLeanDegrees,
      );
      if (analysis == null) continue;
      corners.add(_scoreCorner(analysis, s));
    }

    if (corners.isEmpty) {
      return const RideSkillSummary(
        corners: [],
        sessionScore: 0,
        highlights: [],
        focusTips: [
          'No solid curvas detected — ride a twisty section to build a baseline.',
        ],
      );
    }

    final scores = corners.map((c) => c.score).toList()..sort();
    final avg =
        (corners.fold<int>(0, (a, c) => a + c.score) / corners.length).round();
    final best = corners.reduce((a, b) => a.score >= b.score ? a : b);
    final worst = corners.reduce((a, b) => a.score <= b.score ? a : b);

    final highlights = <String>[
      'Best: ${best.label} · ${best.score}/100',
      if (scores.length >= 3)
        'Median corner score ${scores[scores.length ~/ 2]}/100',
    ];

    final focusTips = <String>[
      ...worst.tips.take(2),
      if (worst.score < 70)
        'Drill: repeat a similar ${worst.label.toLowerCase()} and brake 10–15 m earlier.',
    ];

    return RideSkillSummary(
      corners: corners,
      sessionScore: avg.clamp(0, 100),
      highlights: highlights,
      focusTips: focusTips.take(3).toList(),
    );
  }

  /// Match corners across two rides by fingerprint (same road location).
  static List<({CornerSkill a, CornerSkill b})> matchByFingerprint(
    List<CornerSkill> a,
    List<CornerSkill> b,
  ) {
    final out = <({CornerSkill a, CornerSkill b})>[];
    final used = <int>{};
    for (final ca in a) {
      if (ca.fingerprint.isEmpty) continue;
      var bestJ = -1;
      for (var j = 0; j < b.length; j++) {
        if (used.contains(j)) continue;
        if (b[j].fingerprint == ca.fingerprint) {
          bestJ = j;
          break;
        }
      }
      if (bestJ >= 0) {
        used.add(bestJ);
        out.add((a: ca, b: b[bestJ]));
      }
    }
    return out;
  }

  CornerSkill _scoreCorner(CurvaAnalysis a, RoadStretch stretch) {
    final tips = <String>[];
    var score = 70.0;

    final drop = a.speedDropToApexKmh;
    final gain = a.speedGainFromApexKmh;
    final entry = a.entrySpeedKmh;
    final apex = a.apexSpeedKmh;
    final maxLean = a.maxLeanDegrees;
    final apexLean = a.apexLeanDegrees?.abs() ?? 0;

    // Entry control: huge drop → entered hot / braked hard late.
    if (drop > 35) {
      score -= 18;
      tips.add(
        'Entry hot (${entry.toStringAsFixed(0)}→${apex.toStringAsFixed(0)} km/h). '
        'Brake earlier before tip-in.',
      );
    } else if (drop > 22) {
      score -= 10;
      tips.add('Moderate speed drop to apex — trail brake a touch longer.');
    } else if (drop >= 8 && drop <= 22) {
      score += 8;
    } else if (drop < 5 && entry > 40) {
      score -= 6;
      tips.add('Little speed scrub — confirm you are not carrying too much mid-corner.');
    }

    // Exit drive: rebuild speed after apex.
    if (gain > 12) {
      score += 10;
    } else if (gain < 3 && a.distanceMeters > 40) {
      score -= 8;
      tips.add('Weak exit drive — open throttle sooner once lean starts falling.');
    }

    // Lean commitment at apex vs peak.
    if (maxLean >= 18) {
      score += 6;
      if (apexLean >= maxLean * 0.75) {
        score += 6;
      } else if (apexLean < maxLean * 0.45 && maxLean > 20) {
        score -= 8;
        tips.add(
          'Peak lean not at apex — tip in earlier so the bike is set at the apex.',
        );
      }
    } else if (stretch.headingChangeDeg.abs() > 50 && maxLean < 12) {
      score -= 10;
      tips.add('Big heading change with low lean — check sensor mount or commit more.');
    }

    // Smoothness proxy: duration vs distance (jerky = short chaotic).
    final mps = a.duration.inMilliseconds <= 0
        ? 0.0
        : a.distanceMeters / (a.duration.inMilliseconds / 1000.0);
    if (mps > 2 && mps < 35) {
      score += 2;
    }

    final clamped = score.round().clamp(0, 100);
    if (tips.isEmpty) {
      tips.add('Solid corner — keep this entry/apex rhythm.');
    }

    return CornerSkill(
      analysis: a,
      score: clamped,
      tips: tips,
      fingerprint: stretch.fingerprint ?? '',
    );
  }
}

/// Convenience for tests / future BA pipelines.
int scoreSession(List<int> cornerScores) {
  if (cornerScores.isEmpty) return 0;
  return (cornerScores.reduce((a, b) => a + b) / cornerScores.length)
      .round()
      .clamp(0, 100);
}
