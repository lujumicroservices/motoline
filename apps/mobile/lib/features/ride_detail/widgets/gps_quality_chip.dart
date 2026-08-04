import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/ride_analytics.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// Tiny GPS quality signal: green = fine (no copy); yellow = show short tip.
class GpsQualityChip extends StatelessWidget {
  const GpsQualityChip({super.key, required this.analytics});

  final RideAnalytics analytics;

  /// true = good (green silent), false = issue (yellow + tip), null = unknown.
  static bool? isGood(RideAnalytics a) {
    final avg = a.avgGpsAccuracyM;
    final rate = a.sampleRateHz;
    if (avg == null && rate == null) return null;
    final accuracyOk = avg == null || avg <= 8;
    final rateOk = rate == null || rate >= 0.45;
    return accuracyOk && rateOk;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final good = isGood(analytics);
    if (good == null) return const SizedBox.shrink();

    final color = good ? AppTheme.line : AppTheme.lineHot;
    String? message;
    if (good == false) {
      final avg = analytics.avgGpsAccuracyM;
      final rate = analytics.sampleRateHz;
      if (rate != null && rate < 0.45) {
        message = l10n.gpsQualitySparseTip;
      } else if (avg != null && avg > 12) {
        message = l10n.gpsQualityWeakTip(avg.toStringAsFixed(0));
      } else if (avg != null && avg > 8) {
        message = l10n.gpsQualityFairTip(avg.toStringAsFixed(0));
      } else {
        message = l10n.gpsQualitySparseTip;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'GPS',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
