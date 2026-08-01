import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../models/adventure_camera_status.dart';
import '../providers/adventure_camera_providers.dart';

/// Glove-friendly Connect / Record controls for the ride deck (pre-start + live).
class AdventureCameraRideControls extends ConsumerWidget {
  const AdventureCameraRideControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hydrated = ref.watch(adventureCameraHydratedProvider);
    return hydrated.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (hub) {
        if (!hub.isLabEnabled) return const SizedBox.shrink();
        final status =
            ref.watch(adventureCameraStatusProvider).asData?.value ??
                hub.status;
        final label = switch (status.phase) {
          AdventureCameraPhase.disabled => l10n.labAdventureCameraPhaseOff,
          AdventureCameraPhase.idle => l10n.labAdventureCameraPhaseIdle,
          AdventureCameraPhase.scanning => l10n.labAdventureCameraPhaseScanning,
          AdventureCameraPhase.connecting =>
            l10n.labAdventureCameraPhaseConnecting,
          AdventureCameraPhase.ready => l10n.labAdventureCameraPhaseReady,
          AdventureCameraPhase.recording =>
            l10n.labAdventureCameraPhaseRecording,
          AdventureCameraPhase.error => l10n.labAdventureCameraPhaseError,
        };

        return Material(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'CAM · $label',
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                if (status.message != null && status.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    status.message!,
                    style: GoogleFonts.rajdhani(
                      color: status.phase == AdventureCameraPhase.error
                          ? AppTheme.signal
                          : AppTheme.steel,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: GoogleFonts.exo2(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () => hub.connect(),
                        child: Text(l10n.labAdventureCameraConnect),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          textStyle: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () => hub.disconnect(),
                        child: Text(l10n.labAdventureCameraDisconnect),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.line,
                          foregroundColor: AppTheme.asphalt,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: GoogleFonts.exo2(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () => hub.startRecordingNow(),
                        child: Text(l10n.labAdventureCameraPhaseRecording),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.signal,
                          minimumSize: const Size.fromHeight(56),
                          textStyle: GoogleFonts.exo2(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () => hub.stopRecordingNow(),
                        child: Text(l10n.labAdventureCameraZoneStop),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
