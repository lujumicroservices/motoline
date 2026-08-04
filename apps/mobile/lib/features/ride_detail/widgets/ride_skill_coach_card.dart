import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/corner_skill.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// Compact score on the ride page — improvements live in Skill Lab.
class RideSkillCoachCard extends StatelessWidget {
  const RideSkillCoachCard({
    super.key,
    required this.summary,
    required this.onOpenLab,
  });

  final RideSkillSummary summary;
  final VoidCallback onOpenLab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final score = summary.sessionScore;
    final color = score >= 75
        ? AppTheme.line
        : score >= 55
            ? AppTheme.lineHot
            : AppTheme.signal;

    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpenLab,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      summary.curvaCount == 0
                          ? l10n.skillLabTapHintEmpty
                          : l10n.skillLabTapHint,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$score',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: color,
                ),
              ),
              Text(
                ' /100',
                style: GoogleFonts.rajdhani(color: AppTheme.steel),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppTheme.steel),
            ],
          ),
        ),
      ),
    );
  }
}
