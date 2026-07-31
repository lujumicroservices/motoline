import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/location_service.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Full-screen warm-up while permissions + GNSS settle.
class GpsWarmupPanel extends StatelessWidget {
  const GpsWarmupPanel({
    super.key,
    required this.status,
  });

  final GnssWarmupStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = status.isReady || status.phase == GpsWarmupPhase.timeout;
    final accent = ready
        ? RideVizPalette.leanLeft
        : (status.phase == GpsWarmupPhase.locking
            ? AppTheme.lineHot
            : AppTheme.steel);
    final meters =
        LocationService.warmTargetAccuracyMeters.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Center(
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: status.phase == GpsWarmupPhase.permissions ||
                              status.phase == GpsWarmupPhase.searching
                          ? null
                          : status.lockProgress.clamp(0.08, 1.0),
                      strokeWidth: 5,
                      color: accent,
                      backgroundColor: AppTheme.mist.withValues(alpha: 0.08),
                    ),
                  ),
                  Icon(
                    ready ? Icons.gps_fixed : Icons.gps_not_fixed,
                    size: 36,
                    color: accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            ready ? l10n.gpsReady : l10n.startingRide,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            status.message ?? 'Preparing high-precision GPS…',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.steel,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          if (status.accuracyMeters != null) ...[
            const SizedBox(height: 20),
            _AccuracyMeter(
              accuracyMeters: status.accuracyMeters!,
              progress: status.lockProgress,
              accent: accent,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.gpsWarmHelp(meters),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: AppTheme.steel.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _AccuracyMeter extends StatelessWidget {
  const _AccuracyMeter({
    required this.accuracyMeters,
    required this.progress,
    required this.accent,
  });

  final double accuracyMeters;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final meters =
        LocationService.warmTargetAccuracyMeters.toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.horizontalAccuracy,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.steel,
                ),
              ),
              const Spacer(),
              Text(
                '±${accuracyMeters.toStringAsFixed(1)} m',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.05, 1.0),
              minHeight: 8,
              color: accent,
              backgroundColor: AppTheme.mist.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.lowerBetter(meters),
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.steel),
          ),
        ],
      ),
    );
  }
}

/// Compact live GPS quality chip while recording.
class GpsLockBadge extends StatelessWidget {
  const GpsLockBadge({super.key, this.accuracyMeters});

  final double? accuracyMeters;

  @override
  Widget build(BuildContext context) {
    final acc = accuracyMeters;
    final label = acc == null
        ? 'GPS…'
        : acc <= LocationService.warmTargetAccuracyMeters
            ? 'GPS ready ±${acc.toStringAsFixed(0)} m'
            : acc <= LocationService.maxAcceptAccuracyMeters
                ? 'GPS warm ±${acc.toStringAsFixed(0)} m'
                : 'GPS weak ±${acc.toStringAsFixed(0)} m';

    final color = acc == null
        ? AppTheme.steel
        : acc <= LocationService.warmTargetAccuracyMeters
            ? RideVizPalette.leanLeft
            : acc <= LocationService.maxAcceptAccuracyMeters
                ? AppTheme.lineHot
                : AppTheme.signal;

    final icon = acc == null
        ? Icons.gps_not_fixed
        : acc <= LocationService.warmTargetAccuracyMeters
            ? Icons.gps_fixed
            : Icons.gps_not_fixed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
