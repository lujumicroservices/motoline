import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Toggleable pilot-line map overlays.
@immutable
class MapLayerOptions {
  const MapLayerOptions({
    this.showSpeedColors = true,
    this.showRoadKindContrast = false,
    this.showBrakes = true,
    this.showStartEnd = true,
    this.showPlayhead = true,
    this.showLegend = true,
  });

  final bool showSpeedColors;
  final bool showRoadKindContrast;
  final bool showBrakes;
  final bool showStartEnd;
  final bool showPlayhead;
  final bool showLegend;

  MapLayerOptions copyWith({
    bool? showSpeedColors,
    bool? showRoadKindContrast,
    bool? showBrakes,
    bool? showStartEnd,
    bool? showPlayhead,
    bool? showLegend,
  }) =>
      MapLayerOptions(
        showSpeedColors: showSpeedColors ?? this.showSpeedColors,
        showRoadKindContrast:
            showRoadKindContrast ?? this.showRoadKindContrast,
        showBrakes: showBrakes ?? this.showBrakes,
        showStartEnd: showStartEnd ?? this.showStartEnd,
        showPlayhead: showPlayhead ?? this.showPlayhead,
        showLegend: showLegend ?? this.showLegend,
      );
}

/// Compact chip row to show/hide map layers.
class MapLayerToggles extends StatelessWidget {
  const MapLayerToggles({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final MapLayerOptions options;
  final ValueChanged<MapLayerOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: l10n.mapLayerSpeed,
            selected: options.showSpeedColors,
            color: RideVizPalette.speedMid,
            onSelected: (v) =>
                onChanged(options.copyWith(showSpeedColors: v)),
          ),
          _chip(
            label: l10n.mapLayerRoadKind,
            selected: options.showRoadKindContrast,
            color: RideVizPalette.roadCurva,
            onSelected: (v) =>
                onChanged(options.copyWith(showRoadKindContrast: v)),
          ),
          _chip(
            label: l10n.mapLayerBrakes,
            selected: options.showBrakes,
            color: RideVizPalette.brakeHard,
            onSelected: (v) => onChanged(options.copyWith(showBrakes: v)),
          ),
          _chip(
            label: l10n.mapLayerStartEnd,
            selected: options.showStartEnd,
            color: AppTheme.line,
            onSelected: (v) => onChanged(options.copyWith(showStartEnd: v)),
          ),
          _chip(
            label: l10n.mapLayerPlayhead,
            selected: options.showPlayhead,
            color: AppTheme.lineHot,
            onSelected: (v) => onChanged(options.copyWith(showPlayhead: v)),
          ),
          _chip(
            label: l10n.mapLayerLegend,
            selected: options.showLegend,
            color: AppTheme.steel,
            onSelected: (v) => onChanged(options.copyWith(showLegend: v)),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required Color color,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.asphalt : AppTheme.mist,
          ),
        ),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.9),
        backgroundColor: AppTheme.asphaltElevated,
        side: BorderSide(
          color: selected ? color : AppTheme.mist.withValues(alpha: 0.15),
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
