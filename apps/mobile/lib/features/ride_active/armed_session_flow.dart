import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../l10n/gps_warmup_l10n.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../widgets/app_snack.dart';
import '../lean_lab/lean_lab_review_screen.dart';
import '../rodadas/rodada_post_ride_flow.dart';
import '../watch/watch_providers.dart';
import 'active_ride_screen.dart';
import 'armed_session_nav.dart';

void ensureArmedSessionHub(
  BuildContext context,
  WidgetRef ref, {
  bool userRequested = true,
}) {
  if (!context.mounted) return;
  final nav = ref.read(armedSessionNavProvider);
  final route = ModalRoute.of(context);
  final homeIsVisible = route != null && route.isCurrent && route.isFirst;
  if (!shouldPushArmedHub(
    hubOnStack: nav.hubOnStack,
    homeIsVisible: homeIsVisible,
    hudMinimized: nav.hudMinimized,
    userRequested: userRequested,
  )) {
    return;
  }
  if (nav.hubOnStack) {
    ref.read(armedSessionNavProvider.notifier).hubClosed();
  }
  ref.read(armedSessionNavProvider.notifier).hubOpened();
  Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: kArmedSessionRoute),
          builder: (_) =>
              const ActiveRideScreen(autoStart: false, allowMinimize: true),
        ),
      )
      .whenComplete(() {
        try {
          ref.read(armedSessionNavProvider.notifier).hubClosed();
        } catch (_) {}
      });
}

/// Same screen as the session hub — do not stack a second route.
void openArmedRecordingHud(BuildContext context, WidgetRef ref) {
  ensureArmedSessionHub(context, ref);
}

/// After arm auto-start: open the session if it is not already showing
/// and the user did not minimize it.
void openArmedSessionAfterAutoStart(BuildContext context, WidgetRef ref) {
  if (!context.mounted) return;
  ensureArmedSessionHub(context, ref, userRequested: false);
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
      enqueueAndDrainRideSync(ref.read(syncOutboxServiceProvider), ride.id),
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
    }
    if (!context.mounted) return;
    await continueAfterRideToRodadaShare(
      context: context,
      ref: ref,
      rideId: ride.id,
      replaceCurrent: false,
    );
  } catch (e) {
    if (!context.mounted) return;
    showAppSnackError(context, l10n.userFacingError(e));
  }
}
