import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Compact legend for the shared speed color scale.
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
            child: Row(
              children: [
                Expanded(
                  flex: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          RideVizPalette.speedColor(0),
                          RideVizPalette.speedColor(150),
                          RideVizPalette.speedColor(300),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ColoredBox(color: RideVizPalette.speedOverRed),
                ),
              ],
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
              '300 km/h',
              style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.steel),
            ),
            const SizedBox(width: 8),
            Text(
              'red →',
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: RideVizPalette.speedOverRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
