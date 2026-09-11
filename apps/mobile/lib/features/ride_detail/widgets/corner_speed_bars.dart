import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// Entry → apex → exit speed bars for a scored corner.
class CornerSpeedBars extends StatelessWidget {
  const CornerSpeedBars({
    super.key,
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
