import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../l10n/gps_warmup_l10n.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../lean_lab/lean_lab_review_screen.dart';
import '../rodadas/rodada_post_ride_flow.dart';
import '../watch/watch_providers.dart';
import 'active_ride_screen.dart';
import 'armed_session_nav.dart';
import 'armed_session_screen.dart';

void ensureArmedSessionHub(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  if (ref.read(armedSessionNavProvider).hubOnStack) return;
  ref.read(armedSessionNavProvider.notifier).hubOpened();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kArmedSessionRoute),
      builder: (_) => const ArmedSessionScreen(),
    ),
  );
}

void openArmedRecordingHud(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  if (ref.read(armedSessionNavProvider).hudOnStack) return;
  ref.read(armedSessionNavProvider.notifier).hudOpened();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: kArmedHudRoute),
      builder: (_) => const ActiveRideScreen(
        autoStart: false,
        allowMinimize: true,
      ),
    ),
  );
}

/// After arm auto-start: hub if missing, then HUD unless the user minimized.
void openArmedSessionAfterAutoStart(
  BuildContext context,
  WidgetRef ref,
) {
  if (!context.mounted) return;
  ensureArmedSessionHub(context, ref);
  final recorder = ref.read(rideRecorderProvider);
  final nav = ref.read(armedSessionNavProvider);
  if (shouldAutoPushHud(nav, isRecording: recorder.isRecording)) {
    openArmedRecordingHud(context, ref);
  }
}

/// Stop recording (or just disarm) and leave the armed hub/HUD.
Future<void> completeArmedOrActiveRide(
  BuildContext context,
  WidgetRef ref,
) async {
  final recorder = ref.read(rideRecorderProvider);
  final l10n = context.l10n;

  if (!recorder.isRecording) {
    if (recorder.isArmed) {
      ref.read(armedStateProvider.notifier).disarm();
    }
    ref.read(armedSessionNavProvider.notifier).reset();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    return;
  }

  try {
    await ref.read(activeWatchControllerProvider.notifier).end();
    final ride = await recorder.stop();
    unawaited(
      enqueueAndDrainRideSync(
        ref.read(syncOutboxServiceProvider),
        ride.id,
      ),
    );
    final points = await ref.read(rideDatabaseProvider).getPoints(ride.id);
    await LeanLabService.instance.finalizeTrackStats(
      rideId: ride.id,
      samples: points,
    );
    if (!context.mounted) return;
    ref.read(armedSessionNavProvider.notifier).reset();
    final leanSession = await LeanLabService.instance.getSession(ride.id);
    if (!context.mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    if (leanSession != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => LeanLabReviewScreen(rideId: ride.id),
        ),
      );
      return;
    }
    await continueAfterRideToRodadaShare(
      context: context,
      ref: ref,
      rideId: ride.id,
      replaceCurrent: false,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.userFacingError(e))),
    );
  }
}
