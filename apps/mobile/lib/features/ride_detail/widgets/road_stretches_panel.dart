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

  /// Called with stretch index in the full [stretches] list (curvas only listed).
  final ValueChanged<int>? onSelectStretch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final curvas = <({int index, RoadStretch stretch})>[
      for (var i = 0; i < stretches.length; i++)
        if (stretches[i].kind == RoadKind.curva)
          (index: i, stretch: stretches[i]),
    ];

    if (curvas.isEmpty) {
      return Text(
        l10n.roadStretchesEmpty,
        style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.roadStretchesHelp(curvas.length),
          style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var c = 0; c < curvas.length; c++) ...[
          if (c > 0) const SizedBox(height: 8),
          _StretchCard(
            curvaNumber: c + 1,
            stretch: curvas[c].stretch,
            onTap: onSelectStretch == null
                ? null
                : () => onSelectStretch!(curvas[c].index),
          ),
        ],
      ],
    );
  }
}

class _StretchCard extends StatelessWidget {
  const _StretchCard({
    required this.stretch,
    required this.curvaNumber,
    this.onTap,
  });

  final RoadStretch stretch;
  final int curvaNumber;
  final VoidCallback? onTap;

  String _label(BuildContext context) {
    final l10n = context.l10n;
    return switch (stretch.side) {
      TurnSide.izquierda => l10n.curvaIzquierda,
      TurnSide.derecha => l10n.curvaDerecha,
      TurnSide.none => l10n.curva,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = stretch.side == TurnSide.izquierda
        ? RideVizPalette.leanLeft
        : stretch.side == TurnSide.derecha
            ? RideVizPalette.leanRight
            : AppTheme.lineHot;

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
                      '${l10n.curvaTitle(curvaNumber)} · ${_label(context)}',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(stretch.distanceMeters / 1000).toStringAsFixed(2)} km · '
                      '${formatDuration(stretch.duration)}'
                      ' · Δh ${stretch.headingChangeDeg.abs().toStringAsFixed(0)}°'
                      '${stretch.avgAbsLeanDeg > 0 ? ' · lean ${stretch.avgAbsLeanDeg.toStringAsFixed(0)}°' : ''}'
                      ' · ${l10n.openDetail}',
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.map_outlined,
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
