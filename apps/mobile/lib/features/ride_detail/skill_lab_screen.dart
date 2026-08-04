import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/corner_skill.dart';
import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../l10n/skill_tip_l10n.dart';
import '../../theme/app_theme.dart';
import 'curva_detail_screen.dart';
import 'skill_replay_screen.dart';

/// Visual skill lab: corner scores, mistakes, and how to improve.
class SkillLabScreen extends StatelessWidget {
  const SkillLabScreen({
    super.key,
    required this.samples,
    required this.summary,
    required this.neutralLeanDegrees,
    this.brakeEvents = const [],
  });

  final List<TrackPoint> samples;
  final RideSkillSummary summary;
  final double neutralLeanDegrees;
  final List<BrakeEvent> brakeEvents;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final corners = [...summary.corners]
      ..sort((a, b) => a.score.compareTo(b.score));

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.skillLabTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _SessionHeader(summary: summary),
          const SizedBox(height: 16),
          Text(
            l10n.skillLabFocusTitle,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.skillLabFocusHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (corners.isEmpty)
            Text(
              l10n.skillTipText(const SkillTip(SkillTipId.noCurvasDetected)),
              style: GoogleFonts.rajdhani(color: AppTheme.steel),
            )
          else
            for (final corner in corners) ...[
              _CornerMistakeCard(
                corner: corner,
                onReplay: () => _openReplay(context, corner),
                onOpenDetail: () => _openCurva(context, corner),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _openReplay(BuildContext context, CornerSkill corner) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SkillReplayScreen(
          samples: samples,
          analysis: corner.analysis,
          neutralLeanDegrees: neutralLeanDegrees,
          brakeEvents: brakeEvents,
          title: corner.label,
        ),
      ),
    );
  }

  Future<void> _openCurva(BuildContext context, CornerSkill corner) async {
    final analyses = summary.corners.map((c) => c.analysis).toList();
    final initial =
        summary.corners.indexOf(corner).clamp(0, analyses.length - 1);
    if (analyses.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CurvaDetailScreen(
          samples: samples,
          analyses: analyses,
          initialIndex: initial,
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.summary});

  final RideSkillSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final score = summary.sessionScore;
    final color = score >= 75
        ? AppTheme.line
        : score >= 55
            ? AppTheme.lineHot
            : AppTheme.signal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.skillCoach,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  l10n.skillCurvasRated(summary.curvaCount),
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score',
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              fontSize: 36,
              color: color,
            ),
          ),
          Text(
            ' /100',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CornerMistakeCard extends StatelessWidget {
  const _CornerMistakeCard({
    required this.corner,
    required this.onReplay,
    required this.onOpenDetail,
  });

  final CornerSkill corner;
  final VoidCallback onReplay;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = corner.analysis;
    final score = corner.score;
    final color = score >= 75
        ? AppTheme.line
        : score >= 55
            ? AppTheme.lineHot
            : AppTheme.signal;
    final tips = corner.tips;

    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    corner.label,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '$score',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SpeedBars(
              entry: a.entrySpeedKmh,
              apex: a.apexSpeedKmh,
              exit: a.exitSpeedKmh,
            ),
            const SizedBox(height: 10),
            for (final tip in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      score >= 75
                          ? Icons.check_circle_outline
                          : Icons.lightbulb_outline,
                      size: 16,
                      color: score >= 75 ? AppTheme.line : AppTheme.lineHot,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.skillTipText(tip),
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          height: 1.35,
                          color: AppTheme.mist,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: Text(l10n.skillReplay),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onOpenDetail,
                  child: Text(l10n.openCornerLab),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedBars extends StatelessWidget {
  const _SpeedBars({
    required this.entry,
    required this.apex,
    required this.exit,
  });

  final double entry;
  final double apex;
  final double exit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxV = [entry, apex, exit].fold<double>(1, (m, v) => v > m ? v : m);

    Widget bar(String label, double v, Color color) {
      final t = (v / maxV).clamp(0.08, 1.0);
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 11,
                color: AppTheme.steel,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: t,
                minHeight: 8,
                backgroundColor: AppTheme.asphalt,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${v.toStringAsFixed(0)} ${l10n.kmh}',
              style: GoogleFonts.exo2(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        bar(l10n.entry, entry, AppTheme.mist),
        const SizedBox(width: 10),
        bar(l10n.apex, apex, AppTheme.lineHot),
        const SizedBox(width: 10),
        bar(l10n.exit, exit, AppTheme.line),
      ],
    );
  }
}
