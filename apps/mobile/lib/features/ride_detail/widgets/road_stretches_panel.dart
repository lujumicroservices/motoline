import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/road_kind_detection.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

class RoadStretchesPanel extends StatelessWidget {
  const RoadStretchesPanel({
    super.key,
    required this.stretches,
    this.onSelectStretch,
  });

  final List<RoadStretch> stretches;

  /// Called with stretch index in [stretches] list.
  final ValueChanged<int>? onSelectStretch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (stretches.isEmpty) {
      return Text(
        l10n.roadStretchesEmpty,
        style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
      );
    }

    final rectas = stretches.where((s) => s.kind == RoadKind.recta).length;
    final curvas = stretches.where((s) => s.kind == RoadKind.curva).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.roadStretchesHelp(rectas, curvas),
          style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < stretches.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _StretchCard(
            index: i + 1,
            stretch: stretches[i],
            onTap: onSelectStretch == null
                ? null
                : () => onSelectStretch!(i),
          ),
        ],
      ],
    );
  }
}

class _StretchCard extends StatelessWidget {
  const _StretchCard({
    required this.index,
    required this.stretch,
    this.onTap,
  });

  final int index;
  final RoadStretch stretch;
  final VoidCallback? onTap;

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (stretch.kind) {
      RoadKind.recta => l10n.recta,
      RoadKind.curva => stretch.side == TurnSide.izquierda
          ? l10n.curvaIzquierda
          : stretch.side == TurnSide.derecha
              ? l10n.curvaDerecha
              : l10n.curva,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = stretch.kind == RoadKind.recta
        ? const Color(0xFF7E57C2)
        : stretch.side == TurnSide.izquierda
            ? RideVizPalette.leanLeft
            : stretch.side == TurnSide.derecha
                ? RideVizPalette.leanRight
                : AppTheme.lineHot;

    final isCurva = stretch.kind == RoadKind.curva;

    return Material(
      color: AppTheme.asphalt,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$index · ${_label(context)}',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(stretch.distanceMeters / 1000).toStringAsFixed(2)} km · '
                      '${formatDuration(stretch.duration)}'
                      '${isCurva ? ' · Δh ${stretch.headingChangeDeg.abs().toStringAsFixed(0)}°' : ''}'
                      '${isCurva ? ' · ${l10n.openDetail}' : ''}',
                      style: GoogleFonts.outfit(
                        color: AppTheme.steel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isCurva ? Icons.map_outlined : Icons.play_arrow_rounded,
                color: AppTheme.steel,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
