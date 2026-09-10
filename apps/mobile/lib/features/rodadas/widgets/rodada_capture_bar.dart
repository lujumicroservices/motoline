import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../../ride_active/armed_session_flow.dart';
import '../rodada_capture.dart';
import '../rodada_capture_flow.dart';

/// Pause/resume metric capture while a rodada is live.
class RodadaCaptureBar extends ConsumerWidget {
  const RodadaCaptureBar({super.key, required this.rodadaId, required this.live});

  final String rodadaId;
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!live) return const SizedBox.shrink();
    final l10n = context.l10n;
    final recorder = ref.watch(rideRecorderProvider);
    final dbRide = ref.watch(incompleteRideProvider).valueOrNull;
    final hasLocal = dbRide?.rodadaId == rodadaId;
    final capturing = isActivelyCapturingRodada(
      rodadaId: rodadaId,
      activeRodadaId: recorder.activeRodadaId,
      isRecording: recorder.isRecording,
      metricsHeld: recorder.isRodadaMetricsHeld,
    );
    final showResume = shouldShowResumeRodadaCapture(
      rodadaLive: live,
      rodadaId: rodadaId,
      activeRodadaId: recorder.activeRodadaId,
      isRecording: recorder.isRecording,
      isArmed: recorder.isArmed,
      metricsHeld: recorder.isRodadaMetricsHeld,
      hasLocalRecordingRide: hasLocal,
    );

    if (!capturing && !showResume) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (capturing)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => ensureArmedSessionHub(context, ref),
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(l10n.rodadaCaptureLive),
            ),
          if (showResume) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => resumeRodadaCapture(
                context,
                ref,
                rodadaId: rodadaId,
              ),
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.resumeRodadaCapture),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.rodadaCaptureHeldHint,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
