import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/brake_detection.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/pro_entitlement_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';
import '../../../widgets/pro_upsell.dart';

/// Lists inferred brake events with hardness from speed drop.
/// Free users see a short preview; remaining rows are obfuscated.
class BrakeEventsPanel extends StatelessWidget {
  const BrakeEventsPanel({
    super.key,
    required this.events,
    required this.secondsForIndex,
    required this.isPro,
    this.totalCount,
    this.densityHiddenCount = 0,
    this.zoomed = false,
    this.onSelectIndex,
    this.onZoomToBrake,
    this.onUpgrade,
  });

  final List<BrakeEvent> events;

  /// True ride total for the Pro teaser (badge). Defaults to [events].length.
  final int? totalCount;

  /// Events in the current pool that did not make the density cap.
  final int densityHiddenCount;

  final bool zoomed;

  /// Elapsed ride seconds for a local sample index (view-relative).
  final double Function(int index) secondsForIndex;

  final bool isPro;

  final ValueChanged<int>? onSelectIndex;

  /// Zoom Ride Lab map to this brake (indices are view-relative).
  final ValueChanged<BrakeEvent>? onZoomToBrake;

  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (events.isEmpty) {
      return Text(
        zoomed ? l10n.brakesEmptyZoom : l10n.brakesEmpty,
        style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
      );
    }

    final rideTotal = totalCount ?? events.length;
    final visibleCount =
        isPro ? events.length : freeBrakePreviewCount.clamp(0, events.length);
    // Pro lock is on this slice only; density cap is a separate line.
    final lockedCount =
        isPro ? 0 : (events.length - visibleCount).clamp(0, events.length);
    // Show a couple of blurred placeholders — not every locked row.
    const maxObfuscatedPlaceholders = 2;
    final obfuscatedShown =
        lockedCount.clamp(0, maxObfuscatedPlaceholders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          zoomed ? l10n.brakesHelpZoom : l10n.brakesHelp,
          style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < visibleCount; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _BrakeCard(
            index: i + 1,
            event: events[i],
            atSeconds: secondsForIndex(events[i].startIndex),
            onTap: onSelectIndex == null
                ? null
                : () => onSelectIndex!(events[i].startIndex),
            onZoomMap: onZoomToBrake == null
                ? null
                : () => onZoomToBrake!(events[i]),
          ),
        ],
        if (lockedCount > 0) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < obfuscatedShown; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ObfuscatedBrakeCard(
              index: visibleCount + i + 1,
              onUpgrade: onUpgrade,
            ),
          ],
          const SizedBox(height: 12),
          Material(
            color: RideVizPalette.leanLeft.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onUpgrade,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    const ProBadge(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.brakesProTeaser(visibleCount, rideTotal),
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: RideVizPalette.leanLeft,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (isPro && densityHiddenCount > 0) ...[
          const SizedBox(height: 12),
          Text(
            zoomed
                ? l10n.brakesMoreInStretch(densityHiddenCount)
                : l10n.brakesMoreOverview(densityHiddenCount),
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ObfuscatedBrakeCard extends StatelessWidget {
  const _ObfuscatedBrakeCard({
    required this.index,
    this.onUpgrade,
  });

  final int index;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onUpgrade,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '••:••.•••',
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.steel,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '#$index · •••••',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.steel,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: AppTheme.steel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '••• → ••• · −•• · peak •.•',
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: 0.35,
                        minHeight: 6,
                        color: AppTheme.mist.withValues(alpha: 0.25),
                        backgroundColor: AppTheme.mist.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
                  child: ColoredBox(
                    color: AppTheme.asphalt.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrakeCard extends StatelessWidget {
  const _BrakeCard({
    required this.index,
    required this.event,
    required this.atSeconds,
    this.onTap,
    this.onZoomMap,
  });

  final int index;
  final BrakeEvent event;
  final double atSeconds;
  final VoidCallback? onTap;
  final VoidCallback? onZoomMap;

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
                    formatDurationPrecise(event.duration),
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '#$index · ${_hardnessLabel(context).toUpperCase()}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  if (onZoomMap != null)
                    IconButton(
                      tooltip: l10n.brakeZoomMap,
                      onPressed: onZoomMap,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.map_outlined, size: 22),
                      color: AppTheme.mist,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                l10n.brakeAtTime(formatElapsedPrecise(atSeconds)),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${event.startSpeedKmh.toStringAsFixed(0)} → '
                '${event.endSpeedKmh.toStringAsFixed(0)} ${l10n.kmh}  ·  '
                '−${event.speedDropKmh.toStringAsFixed(0)} ${l10n.kmh}  ·  '
                '${l10n.brakePeakDecel(event.peakDecelMps2.toStringAsFixed(1))}',
                style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
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
