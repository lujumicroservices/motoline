import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/brake_detection.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
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
    final l10n = context.l10n;
    if (events.isEmpty) {
      return Text(
        l10n.brakesEmpty,
        style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.brakesHelp,
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

  String _hardnessLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (event.hardness) {
      BrakeHardness.light => l10n.brakeLight,
      BrakeHardness.medium => l10n.brakeMedium,
      BrakeHardness.hard => l10n.brakeHard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    '#$index · ${_hardnessLabel(context).toUpperCase()}',
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
                '${event.endSpeedKmh.toStringAsFixed(0)} ${l10n.kmh}  ·  '
                '−${event.speedDropKmh.toStringAsFixed(0)} ${l10n.kmh}  ·  '
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
