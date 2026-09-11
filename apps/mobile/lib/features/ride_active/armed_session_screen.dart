import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/force_start_prefs.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snack.dart';
import '../rodadas/rodada_capture.dart';
import '../rodadas/rodada_capture_flow.dart';
import 'armed_session_flow.dart';
import 'armed_session_nav.dart';
import 'widgets/recording_rec_badge.dart';

/// Session hub while armed: status, enter/leave the recording HUD, end ride.
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
      if (shouldAutoPushHud(
        nav,
        isRecording: recorder.isRecording,
        rodadaMetricsHeld: recorder.isRodadaMetricsHeld,
      )) {
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
    final ride = snap?.ride ?? recorder.activeRide;

    ref.listen(autoStartEventsProvider, (previous, next) {
      next.whenData((_) {
        if (!mounted) return;
        final nav = ref.read(armedSessionNavProvider);
        if (shouldAutoPushHud(
          nav,
          isRecording: true,
          rodadaMetricsHeld: recorder.isRodadaMetricsHeld,
        )) {
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
          const Spacer(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!recording &&
                      showForceStartArmedButton(
                        ref.watch(forceStartArmedVisibleProvider),
                      )) ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(rideRecorderProvider)
                              .forceStartFromArm();
                        } catch (e) {
                          if (!context.mounted) return;
                          showAppSnackError(context, '$e');
                        }
                      },
                      icon: const Icon(Icons.bug_report_outlined, size: 18),
                      label: Text(l10n.armedSessionForceStart),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: AppTheme.steel,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
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
                    onPressed: () {
                      if (shouldUseRodadaPauseAction(recorder.activeRodadaId)) {
                        holdRodadaCaptureAndReturn(context, ref);
                      } else {
                        completeArmedOrActiveRide(context, ref);
                      }
                    },
                    child: Text(
                      shouldUseRodadaPauseAction(recorder.activeRodadaId)
                          ? l10n.pauseRodadaCapture
                          : l10n.armedSessionEndArm,
                    ),
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
