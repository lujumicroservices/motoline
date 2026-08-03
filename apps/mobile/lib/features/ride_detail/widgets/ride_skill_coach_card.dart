import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/corner_skill.dart';
import '../../../theme/app_theme.dart';

/// Post-ride skill coach — session score + actionable tips (not GPS lock).
class RideSkillCoachCard extends StatelessWidget {
  const RideSkillCoachCard({
    super.key,
    required this.summary,
    this.onOpenCorners,
  });

  final RideSkillSummary summary;
  final VoidCallback? onOpenCorners;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Skill coach',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '${summary.sessionScore}',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  color: AppTheme.line,
                ),
              ),
              Text(
                ' /100',
                style: GoogleFonts.rajdhani(color: AppTheme.steel),
              ),
            ],
          ),
          Text(
            '${summary.curvaCount} curvas rated · fingerprints for peer compare',
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
            ),
          ),
          if (summary.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final h in summary.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $h',
                  style: GoogleFonts.rajdhani(fontSize: 14),
                ),
              ),
          ],
          if (summary.focusTips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Improve next ride',
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.lineHot,
              ),
            ),
            const SizedBox(height: 4),
            for (final t in summary.focusTips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  t,
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    height: 1.35,
                    color: AppTheme.mist,
                  ),
                ),
              ),
          ],
          if (onOpenCorners != null && summary.corners.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onOpenCorners,
              child: const Text('Open corner lab'),
            ),
          ],
        ],
      ),
    );
  }
}
