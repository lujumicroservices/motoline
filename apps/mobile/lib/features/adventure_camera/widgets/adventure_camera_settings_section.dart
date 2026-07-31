import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../adventure_camera_prefs.dart';
import '../models/adventure_camera_status.dart';
import '../providers/adventure_camera_providers.dart';

/// Settings → Lab block. Entirely optional; default off.
class AdventureCameraSettingsSection extends ConsumerWidget {
  const AdventureCameraSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hydrated = ref.watch(adventureCameraHydratedProvider);
    final statusAsync = ref.watch(adventureCameraStatusProvider);
    final backendAsync = ref.watch(adventureCameraBackendProvider);

    return hydrated.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.signal)),
      data: (hub) {
        final enabled = hub.isLabEnabled;
        final status = statusAsync.asData?.value ?? hub.status;
        final backend =
            backendAsync.asData?.value ?? AdventureCameraPrefs.backendGoPro;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.labSection,
              style: GoogleFonts.barlowCondensed(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.labAdventureCameraHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.labAdventureCameraEnable,
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.labAdventureCameraEnableHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              value: enabled,
              activeThumbColor: AppTheme.lineHot,
              onChanged: (v) async {
                await hub.setLabEnabled(v);
                ref.invalidate(adventureCameraHydratedProvider);
                ref.invalidate(adventureCameraBackendProvider);
              },
            ),
            if (enabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.labAdventureCameraSyncRide,
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.labAdventureCameraSyncRideHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
                value: hub.syncWithRide,
                activeThumbColor: AppTheme.lineHot,
                onChanged: (v) async {
                  await hub.setSyncWithRide(v);
                  ref.invalidate(adventureCameraHydratedProvider);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.labAdventureCameraSyncPause,
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.labAdventureCameraSyncPauseHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
                value: hub.syncPauseWithAutoPause,
                activeThumbColor: AppTheme.lineHot,
                onChanged: (v) async {
                  await hub.setSyncPause(v);
                  ref.invalidate(adventureCameraHydratedProvider);
                },
              ),
              const SizedBox(height: 8),
              Text(
                l10n.labAdventureCameraBackend,
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: AdventureCameraPrefs.backendGoPro,
                    label: Text(l10n.labAdventureCameraBackendGoPro),
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: AdventureCameraPrefs.backendSimulated,
                    label: Text(l10n.labAdventureCameraBackendSim),
                    icon: const Icon(Icons.science_outlined, size: 16),
                  ),
                ],
                selected: {backend},
                onSelectionChanged: (set) async {
                  final v = set.first;
                  await hub.setBackend(v);
                  ref.invalidate(adventureCameraBackendProvider);
                  ref.invalidate(adventureCameraHydratedProvider);
                },
              ),
              const SizedBox(height: 12),
              _StatusLine(status: status),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await hub.connect();
                      },
                      icon: const Icon(Icons.bluetooth_searching, size: 18),
                      label: Text(l10n.labAdventureCameraConnect),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await hub.disconnect();
                      },
                      icon: const Icon(Icons.link_off, size: 18),
                      label: Text(l10n.labAdventureCameraDisconnect),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final AdventureCameraStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (status.phase) {
      AdventureCameraPhase.disabled => l10n.labAdventureCameraPhaseOff,
      AdventureCameraPhase.idle => l10n.labAdventureCameraPhaseIdle,
      AdventureCameraPhase.scanning => l10n.labAdventureCameraPhaseScanning,
      AdventureCameraPhase.connecting => l10n.labAdventureCameraPhaseConnecting,
      AdventureCameraPhase.ready => l10n.labAdventureCameraPhaseReady,
      AdventureCameraPhase.recording => l10n.labAdventureCameraPhaseRecording,
      AdventureCameraPhase.error => l10n.labAdventureCameraPhaseError,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.phase == AdventureCameraPhase.error
              ? AppTheme.signal.withValues(alpha: 0.5)
              : AppTheme.mist.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          if (status.deviceName != null) ...[
            const SizedBox(height: 2),
            Text(
              status.deviceName!,
              style: const TextStyle(color: AppTheme.steel, fontSize: 12),
            ),
          ],
          if (status.message != null && status.message!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              status.message!,
              style: TextStyle(
                color: status.phase == AdventureCameraPhase.error
                    ? AppTheme.signal
                    : AppTheme.steel,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
