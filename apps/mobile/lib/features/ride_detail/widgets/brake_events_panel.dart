import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/brake_detection.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Lists inferred brake events with hardness from speed drop.
class BrakeEventsPanel extends StatelessWidget {
  const BrakeEventsPanel({
    super.key,
    required this.events,
    this.onSelectIndex,
  });

  final List<BrakeEvent> events;
  final ValueChanged<int>? onSelectIndex;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'No clear brake pulses from GPS speed. '
          'Harder stops outdoors usually show as yellow/orange/red hits.',
          style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Braking (from speed)',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Inferred from how fast speed falls — not a brake sensor. '
          'Tap a hit to jump the playhead.',
          style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _BrakeCard(
            index: i + 1,
            event: events[i],
            onTap: onSelectIndex == null
                ? null
                : () => onSelectIndex!(events[i].startIndex),
          ),
        ],
      ],
    );
  }
}

class _BrakeCard extends StatelessWidget {
  const _BrakeCard({
    required this.index,
    required this.event,
    this.onTap,
  });

  final int index;
  final BrakeEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = RideVizPalette.brakeColor(event.hardness);
    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: color, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#$index · ${event.hardnessLabel.toUpperCase()}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatDuration(event.duration),
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${event.startSpeedKmh.toStringAsFixed(0)} → '
                '${event.endSpeedKmh.toStringAsFixed(0)} km/h  ·  '
                '−${event.speedDropKmh.toStringAsFixed(0)} km/h  ·  '
                'peak ${event.peakDecelMps2.toStringAsFixed(1)} m/s²',
                style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: event.hardnessFraction,
                  minHeight: 6,
                  color: color,
                  backgroundColor: AppTheme.mist.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
