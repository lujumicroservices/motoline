import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/models/ride.dart';
import '../../l10n/gps_warmup_l10n.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../widgets/app_snack.dart';
import '../ride_active/armed_session_flow.dart';
import '../ride_active/armed_session_nav.dart';
import '../ride_active/location_permission_gate.dart';
import '../ride_active/widgets/upright_freeze_sheet.dart';
import '../watch/watch_providers.dart';
import 'rodada_detail_screen.dart';

/// Pause metric capture and return to the rodada (do not complete the ride).
Future<void> holdRodadaCaptureAndReturn(
  BuildContext context,
  WidgetRef ref,
) async {
  final recorder = ref.read(rideRecorderProvider);
  final rodadaId = recorder.activeRodadaId;
  if (rodadaId == null || rodadaId.isEmpty) {
    await completeArmedOrActiveRide(context, ref);
    return;
  }

  recorder.holdRodadaMetrics();
  ref.read(armedSessionNavProvider.notifier).reset();

  final navigator = Navigator.of(context);
  Route<dynamic>? remaining;
  navigator.popUntil((route) {
    final name = route.settings.name;
    if (name == kArmedHudRoute || name == kArmedSessionRoute) return false;
    remaining = route;
    return true;
  });
  if (!navigator.mounted) return;
  final onRodada = remaining?.settings.name == kRodadaDetailRoute &&
      remaining?.settings.arguments == rodadaId;
  if (!onRodada) {
    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: kRodadaDetailRoute, arguments: rodadaId),
        builder: (_) => RodadaDetailScreen(
          rodadaId: rodadaId,
          initialTab: 1,
        ),
      ),
    );
  }
}

/// Re-arm or continue the same ride, then open the recording HUD.
Future<void> resumeRodadaCapture(
  BuildContext context,
  WidgetRef ref, {
  required String rodadaId,
}) async {
  final recorder = ref.read(rideRecorderProvider);
  try {
    if (!await LocationPermissionGate.requestForRecording(context)) {
      return;
    }
    if (!context.mounted) return;

    if (recorder.isArmed && !recorder.isRecording) {
      if (context.mounted) ensureArmedSessionHub(context, ref);
      return;
    }

    var ride = await recorder.resumeRodadaMetrics(rodadaId: rodadaId);
    if (ride == null && !recorder.isArmed && !recorder.isRecording) {
      if (!context.mounted) return;
      final ok = await freezeThenArm(
        context,
        ref,
        autoBeginHold: true,
        rodadaId: rodadaId,
      );
      if (!ok || !context.mounted) return;
      ensureArmedSessionHub(context, ref);
      return;
    }

    if (!context.mounted) return;
    ref.read(armedSessionNavProvider.notifier).reset();
    ensureArmedSessionHub(context, ref);
    if (recorder.isRecording) {
      openArmedRecordingHud(context, ref);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(context.l10n.userFacingError(e)),
    );
  }
}

/// Complete the local rodada ride when the outing ends or the rider leaves.
Future<void> completeRodadaCaptureIfNeeded(
  WidgetRef ref, {
  required String rodadaId,
}) async {
  final recorder = ref.read(rideRecorderProvider);
  final db = ref.read(rideDatabaseProvider);
  try {
    Ride? completed;
    final active = recorder.activeRide;
    if (active != null &&
        active.rodadaId == rodadaId &&
        recorder.isRecording) {
      await ref.read(activeWatchControllerProvider.notifier).end();
      completed = await recorder.stop();
    } else {
      final leftover = await db.getRecordingRideForRodada(rodadaId);
      if (leftover != null) {
        await ref.read(activeWatchControllerProvider.notifier).end();
        completed = await recorder.finalizeRecovered(leftover.id);
      }
    }
    if (completed == null) return;
    unawaited(
      enqueueAndDrainRideSync(ref.read(syncOutboxServiceProvider), completed.id),
    );
    final points = await db.getPoints(completed.id);
    await LeanLabService.instance.finalizeTrackStats(
      rideId: completed.id,
      samples: points,
    );
    ref.invalidate(ridesListProvider);
    ref.invalidate(incompleteRideProvider);
  } catch (e) {
    debugPrint('completeRodadaCaptureIfNeeded $rodadaId: $e');
  }
}
