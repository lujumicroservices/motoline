import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/ride_stretch.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import 'armed_session_flow.dart';
import 'armed_session_nav.dart';
import 'widgets/recording_rec_badge.dart';

/// Session hub while armed: stretches, enter/leave the recording HUD, end ride.
class ArmedSessionScreen extends ConsumerStatefulWidget {
  const ArmedSessionScreen({super.key});

  @override
  ConsumerState<ArmedSessionScreen> createState() => _ArmedSessionScreenState();
}

class _ArmedSessionScreenState extends ConsumerState<ArmedSessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(armedSessionNavProvider.notifier).hubOpened();
      final recorder = ref.read(rideRecorderProvider);
      final nav = ref.read(armedSessionNavProvider);
      if (shouldAutoPushHud(nav, isRecording: recorder.isRecording)) {
        openArmedRecordingHud(context, ref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recorder = ref.watch(rideRecorderProvider);
    final snapAsync = ref.watch(activeRideProvider);
    final snap = snapAsync.valueOrNull;
    final recording = recorder.isRecording;
    final paused = snap?.isPaused ?? recorder.isPaused;
    final stretches = snap?.stretches ?? recorder.sessionStretches;
    final ride = snap?.ride ?? recorder.activeRide;

    ref.listen(autoStartEventsProvider, (previous, next) {
      next.whenData((_) {
        if (!mounted) return;
        final nav = ref.read(armedSessionNavProvider);
        if (shouldAutoPushHud(nav, isRecording: true)) {
          openArmedRecordingHud(context, ref);
        }
      });
    });

    final statusLabel = !recording
        ? l10n.waitingForMotion
        : paused
        ? l10n.pausedLabel
        : l10n.recording;
    final statusColor = !recording
        ? AppTheme.lineHot
        : paused
        ? AppTheme.lineHot
        : AppTheme.signal;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.armedSessionTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.armedSessionMinimize,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.asphaltElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (recording)
                        RecordingRecBadge(
                          label: paused ? l10n.pausedLabel : l10n.recordingRec,
                          paused: paused,
                          compact: true,
                        )
                      else
                        Icon(Icons.motion_photos_auto, color: statusColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recording
                        ? l10n.armedSessionLiveHelp
                        : l10n.armedSessionWaitingHelp,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                  ),
                  if (ride != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${ride.distanceKm.toStringAsFixed(2)} km  ·  '
                      '${formatDuration(DateTime.now().difference(ride.startedAt))}  ·  '
                      '${ride.pointCount}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.mist,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: stretches.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Text(
                        l10n.armedSessionStretchesEmpty,
                        style: const TextStyle(
                          color: AppTheme.steel,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: stretches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final stretch = stretches[stretches.length - 1 - i];
                      return _StretchTile(stretch: stretch);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recording)
                    FilledButton.tonalIcon(
                      onPressed: () => openArmedRecordingHud(context, ref),
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(l10n.armedSessionWatchRecording),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  if (recording) const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.signal,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => completeArmedOrActiveRide(context, ref),
                    child: Text(l10n.armedSessionEndArm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StretchTile extends StatelessWidget {
  const _StretchTile({required this.stretch});

  final RideStretch stretch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = DateFormat.Hm().format(stretch.startedAt.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.line.withValues(alpha: 0.2),
            child: Text(
              '${stretch.index}',
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                color: AppTheme.line,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.armedSessionStretchN(stretch.index),
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${stretch.distanceKm.toStringAsFixed(2)} km',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatDuration(stretch.duration),
            style: const TextStyle(color: AppTheme.steel, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
