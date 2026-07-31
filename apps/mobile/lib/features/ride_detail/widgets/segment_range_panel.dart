import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';
import '../../../widgets/pro_upsell.dart';

/// Range picker to select a road segment for zoom + metrics.
/// Locked for Free — Pro unlocks selecting a sub-portion of the ride.
class SegmentRangePanel extends StatelessWidget {
  const SegmentRangePanel({
    super.key,
    required this.totalPoints,
    required this.startIndex,
    required this.endIndex,
    required this.startSeconds,
    required this.endSeconds,
    required this.zoomed,
    required this.isPro,
    required this.onRangeChanged,
    required this.onZoom,
    required this.onClear,
    this.onUpgrade,
  });

  final int totalPoints;
  final int startIndex;
  final int endIndex;
  final double startSeconds;
  final double endSeconds;
  final bool zoomed;
  final bool isPro;
  final void Function(int start, int end) onRangeChanged;
  final VoidCallback onZoom;
  final VoidCallback onClear;
  final VoidCallback? onUpgrade;

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
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: zoomed ? RideVizPalette.leanLeft : AppTheme.steel,
                ),
              ),
              if (!isPro) ...[
                const SizedBox(width: 8),
                const ProBadge(),
              ],
              const Spacer(),
              Text(
                '${_fmt(startSeconds)} → ${_fmt(endSeconds)}',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPro ? null : AppTheme.steel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isPro
                ? (zoomed ? l10n.segmentHintZoomed : l10n.segmentHint)
                : l10n.segmentProLocked,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: !isPro,
            child: Opacity(
              opacity: isPro ? 1 : 0.45,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: RideVizPalette.leanLeft,
                  inactiveTrackColor: AppTheme.mist.withValues(alpha: 0.12),
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayColor:
                      RideVizPalette.leanLeft.withValues(alpha: 0.15),
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
            ),
          ),
          Row(
            children: [
              Text(
                'pts ${startIndex + 1}–${endIndex + 1} / $totalPoints',
                style: GoogleFonts.rajdhani(fontSize: 12, color: AppTheme.steel),
              ),
              const Spacer(),
              if (!isPro)
                FilledButton.tonal(
                  onPressed: onUpgrade,
                  child: Text(l10n.upgradeToPro),
                )
              else if (zoomed)
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
