import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Compact legend for the high-contrast speed color scale.
class SpeedColorLegend extends StatelessWidget {
  const SpeedColorLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    for (final stop in RideVizPalette.speedStops) stop.$2,
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '0',
              style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.steel),
            ),
            const Spacer(),
            Text(
              'blue→lime→yellow→red→magenta',
              style: GoogleFonts.outfit(fontSize: 9, color: AppTheme.steel),
            ),
            const Spacer(),
            Text(
              '300',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppTheme.mist,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
