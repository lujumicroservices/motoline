import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../models/adventure_camera_status.dart';
import '../providers/adventure_camera_providers.dart';

/// Compact CAM chip for the active-ride app bar (only when lab is on).
class AdventureCameraStatusChip extends ConsumerWidget {
  const AdventureCameraStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(adventureCameraHydratedProvider);
    final hub = hydrated.asData?.value;
    if (hub == null || !hub.isLabEnabled) {
      return const SizedBox.shrink();
    }

    final status =
        ref.watch(adventureCameraStatusProvider).asData?.value ?? hub.status;

    final color = switch (status.phase) {
      AdventureCameraPhase.recording => AppTheme.signal,
      AdventureCameraPhase.ready => AppTheme.line,
      AdventureCameraPhase.error => AppTheme.signal,
      AdventureCameraPhase.scanning ||
      AdventureCameraPhase.connecting =>
        AppTheme.lineHot,
      _ => AppTheme.steel,
    };

    final label = switch (status.phase) {
      AdventureCameraPhase.recording =>
        (status.memberCount != null && status.memberCount! > 1)
            ? 'CAM ${status.recordingCount ?? 0}/${status.memberCount}'
            : 'CAM',
      AdventureCameraPhase.ready =>
        (status.memberCount != null && status.memberCount! > 1)
            ? 'CAM ${status.readyCount ?? 0}/${status.memberCount}'
            : 'CAM',
      AdventureCameraPhase.error => 'CAM!',
      AdventureCameraPhase.scanning => '…',
      AdventureCameraPhase.connecting => '…',
      _ => 'CAM',
    };

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: status.phase == AdventureCameraPhase.recording
                    ? AppTheme.signal
                    : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.exo2(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
