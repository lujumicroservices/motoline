import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Range picker to select a road segment for zoom + metrics.
class SegmentRangePanel extends StatelessWidget {
  const SegmentRangePanel({
    super.key,
    required this.totalPoints,
    required this.startIndex,
    required this.endIndex,
    required this.startSeconds,
    required this.endSeconds,
    required this.zoomed,
    required this.onRangeChanged,
    required this.onZoom,
    required this.onClear,
  });

  final int totalPoints;
  final int startIndex;
  final int endIndex;
  final double startSeconds;
  final double endSeconds;
  final bool zoomed;
  final void Function(int start, int end) onRangeChanged;
  final VoidCallback onZoom;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (totalPoints < 2) return const SizedBox.shrink();

    final l10n = context.l10n;
    final maxIndex = (totalPoints - 1).toDouble();
    final start = startIndex.clamp(0, totalPoints - 1).toDouble();
    final end = endIndex.clamp(startIndex, totalPoints - 1).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: zoomed
              ? RideVizPalette.leanLeft.withValues(alpha: 0.45)
              : AppTheme.mist.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                zoomed ? l10n.segmentZoom : l10n.segment,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: zoomed ? RideVizPalette.leanLeft : AppTheme.steel,
                ),
              ),
              const Spacer(),
              Text(
                '${_fmt(startSeconds)} → ${_fmt(endSeconds)}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            zoomed ? l10n.segmentHintZoomed : l10n.segmentHint,
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: RideVizPalette.leanLeft,
              inactiveTrackColor: AppTheme.mist.withValues(alpha: 0.12),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              overlayColor: RideVizPalette.leanLeft.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: RangeSlider(
              values: RangeValues(start, end),
              min: 0,
              max: maxIndex,
              divisions: totalPoints > 2 ? totalPoints - 1 : null,
              labels: RangeLabels(
                'A ${startIndex + 1}',
                'B ${endIndex + 1}',
              ),
              onChanged: (v) {
                onRangeChanged(v.start.round(), v.end.round());
              },
            ),
          ),
          Row(
            children: [
              Text(
                'pts ${startIndex + 1}–${endIndex + 1} / $totalPoints',
                style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.steel),
              ),
              const Spacer(),
              if (zoomed)
                TextButton(
                  onPressed: onClear,
                  child: Text(l10n.fullRide),
                )
              else
                FilledButton.tonal(
                  onPressed: endIndex > startIndex ? onZoom : null,
                  child: Text(l10n.zoomToSegment),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double s) => formatDuration(Duration(seconds: s.round()));
}
