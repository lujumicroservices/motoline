import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/corner_skill.dart';
import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../l10n/skill_tip_l10n.dart';
import '../../theme/app_theme.dart';
import 'skill_replay_screen.dart';
import 'widgets/corner_shape_thumb.dart';

/// Visual skill lab: corner scores, mistakes, and how to improve.
class SkillLabScreen extends StatelessWidget {
  const SkillLabScreen({
    super.key,
    required this.samples,
    required this.summary,
    required this.neutralLeanDegrees,
    this.brakeEvents = const [],
    this.localRideId,
  });

  final List<TrackPoint> samples;
  final RideSkillSummary summary;
  final double neutralLeanDegrees;
  final List<BrakeEvent> brakeEvents;
  final String? localRideId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final corners = [...summary.corners]
      ..sort(
        (a, b) => a.analysis.entryIndex.compareTo(b.analysis.entryIndex),
      );

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
            for (var i = 0; i < corners.length; i++) ...[
              _CornerMistakeCard(
                samples: samples,
                corner: corners[i],
                rideOrder: i + 1,
                onOpen: () => _openReplay(context, corners, i),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Future<void> _openReplay(
    BuildContext context,
    List<CornerSkill> corners,
    int index,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SkillReplayScreen(
          samples: samples,
          corners: corners,
          initialIndex: index,
          neutralLeanDegrees: neutralLeanDegrees,
          brakeEvents: brakeEvents,
          localRideId: localRideId,
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
    required this.samples,
    required this.corner,
    required this.rideOrder,
    required this.onOpen,
  });

  final List<TrackPoint> samples;
  final CornerSkill corner;
  final int rideOrder;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final score = corner.score;
    final color = score >= 75
        ? AppTheme.line
        : score >= 55
            ? AppTheme.lineHot
            : AppTheme.signal;

    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Stack(
          children: [
            CornerShapeThumb(
              samples: samples,
              analysis: corner.analysis,
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$rideOrder · ${corner.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.mist,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.asphalt.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      '$score',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
