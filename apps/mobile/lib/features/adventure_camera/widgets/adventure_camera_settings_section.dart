import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/track_point.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../adventure_camera_prefs.dart';
import '../models/adventure_camera_status.dart';
import '../models/camera_member.dart';
import '../models/camera_zone.dart';
import '../providers/adventure_camera_providers.dart';
import 'camera_zones_map_screen.dart';

/// Settings → Lab block. Entirely optional; default off.
class AdventureCameraSettingsSection extends ConsumerWidget {
  const AdventureCameraSettingsSection({super.key});

  Future<List<TrackPoint>> _recentTrack(WidgetRef ref) async {
    final rides = await ref.read(ridesListProvider.future);
    if (rides.isEmpty) return const [];
    final ride = rides.first;
    return ref.read(rideDatabaseProvider).getPoints(ride.id);
  }

  Future<void> _editZones(BuildContext context, WidgetRef ref) async {
    final hub = ref.read(adventureCameraHubProvider);
    final track = await _recentTrack(ref);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<List<CameraZone>>(
      MaterialPageRoute(
        builder: (_) => CameraZonesMapScreen(
          initialZones: hub.zones,
          trackPoints: track,
        ),
      ),
    );
    if (result == null) return;
    await hub.setZones(result);
    ref.invalidate(adventureCameraHydratedProvider);
  }

  Future<void> _addCamera(BuildContext context, WidgetRef ref) async {
    final hub = ref.read(adventureCameraHubProvider);
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.labAdventureCameraGroupScanning)),
          ],
        ),
      ),
    );
    try {
      final hits = await hub.scanForCameras();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      final known = hub.cameraGroup.map((m) => m.remoteId).toSet();
      final fresh = hits.where((h) => !known.contains(h.remoteId)).toList();
      if (fresh.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.labAdventureCameraGroupNoneFound)),
        );
        return;
      }
      final picked = await showDialog<GoProScanHit>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: AppTheme.asphaltElevated,
            title: Text(
              l10n.labAdventureCameraGroupPick,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: fresh.length,
                itemBuilder: (_, i) {
                  final hit = fresh[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(hit.displayName),
                    subtitle: Text(
                      hit.rssi == null
                          ? hit.remoteId
                          : '${hit.remoteId}  ·  ${hit.rssi} dBm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => Navigator.pop(ctx, hit),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
      if (picked == null) return;
      await hub.addCameraToGroup(picked);
      ref.invalidate(adventureCameraHydratedProvider);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

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
        final zoneCount = hub.zones.length;

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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.labAdventureCameraZonesEnable,
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.labAdventureCameraZonesEnableHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
                value: hub.zonesEnabled,
                activeThumbColor: AppTheme.lineHot,
                onChanged: (v) async {
                  await hub.setZonesEnabled(v);
                  ref.invalidate(adventureCameraHydratedProvider);
                },
              ),
              if (hub.zonesEnabled) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.labAdventureCameraZonesEdit,
                    style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    zoneCount == 0
                        ? l10n.labAdventureCameraZonesEmpty
                        : l10n.labAdventureCameraZonesCount(zoneCount),
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.map_outlined),
                  onTap: () => _editZones(context, ref),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.labAdventureCameraAggressive,
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.labAdventureCameraAggressiveHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
                value: hub.aggressiveEnabled,
                activeThumbColor: AppTheme.lineHot,
                onChanged: (v) async {
                  await hub.setAggressiveEnabled(v);
                  ref.invalidate(adventureCameraHydratedProvider);
                },
              ),
              const SizedBox(height: 14),
              Text(
                l10n.labAdventureCameraGroup,
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.labAdventureCameraGroupHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              if (hub.cameraGroup.isEmpty)
                Text(
                  l10n.labAdventureCameraGroupEmpty,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                )
              else
                ...[
                  for (final member in hub.cameraGroup)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: IconButton(
                        tooltip: l10n.labAdventureCameraGroupRemove,
                        onPressed: () async {
                          await hub.removeCameraFromGroup(member.id);
                          ref.invalidate(adventureCameraHydratedProvider);
                        },
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                      title: Text(
                        member.displayName,
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        member.remoteId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 11,
                        ),
                      ),
                      value: member.enabled,
                      activeThumbColor: AppTheme.lineHot,
                      onChanged: (v) async {
                        await hub.setCameraEnabled(member.id, v);
                        ref.invalidate(adventureCameraHydratedProvider);
                      },
                    ),
                ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _addCamera(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.labAdventureCameraGroupAdd),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  initiallyExpanded: false,
                  title: Text(
                    l10n.labAdventureCameraGroupSetupHelp,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.mist,
                    ),
                  ),
                  leading: const Icon(
                    Icons.help_outline,
                    size: 20,
                    color: AppTheme.lineHot,
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.asphaltElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.mist.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        l10n.labAdventureCameraGroupSetupBody,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
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
