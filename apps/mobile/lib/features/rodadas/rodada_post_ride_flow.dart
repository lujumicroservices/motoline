import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ride.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../providers/ride_providers.dart';
import '../reel/reel_compose_screen.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'photos/ride_photo_capture.dart';
import 'photos/ride_photo_gallery_scan.dart';
import 'photos/ride_photo_import_sheet.dart';
import 'rodada_providers.dart';

class LinkedRodadaRide {
  const LinkedRodadaRide({
    required this.rodadaId,
    this.cloudRideId,
  });

  final String rodadaId;
  final String? cloudRideId;
}

/// Sync + attach the local ride to the rider's live/open rodada.
Future<LinkedRodadaRide?> autoLinkRideToRodada({
  required WidgetRef ref,
  required String localRideId,
}) async {
  if (!SupabaseBootstrap.isReady) return null;
  final repo = ref.read(rodadaRepositoryProvider);
  final rodada = await repo.findAttachableRodada();
  if (rodada == null) return null;

  try {
    await enqueueAndDrainRideSync(
      ref.read(syncOutboxServiceProvider),
      localRideId,
    );
  } catch (_) {}

  var cloudId = await repo.cloudRideIdForLocal(localRideId);
  if (cloudId == null) {
    try {
      await ref.read(rideSyncServiceProvider).syncRide(localRideId);
      cloudId = await repo.cloudRideIdForLocal(localRideId);
    } catch (_) {}
  }
  if (cloudId != null) {
    await repo.linkRideToRodada(cloudRideId: cloudId, rodadaId: rodada.id);
  }
  ref.invalidate(rodadaRidesProvider(rodada.id));
  ref.invalidate(myRodadaMembershipProvider(rodada.id));
  return LinkedRodadaRide(rodadaId: rodada.id, cloudRideId: cloudId);
}

/// After labels / lean lab: import carrete photos, then offer the reel.
Future<void> continueAfterRideToRodadaShare({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  bool replaceCurrent = true,
}) async {
  LinkedRodadaRide? linked;
  try {
    linked = await autoLinkRideToRodada(ref: ref, localRideId: rideId);
  } catch (_) {}

  if (!context.mounted) return;
  if (linked == null) {
    _openAfterRide(
      context,
      RideDetailScreen(rideId: rideId),
      replaceCurrent: replaceCurrent,
    );
    return;
  }

  final ride = await ref.read(rideProvider(rideId).future);
  final points = await ref.read(ridePointsProvider(rideId).future);
  if (!context.mounted) return;
  if (ride != null && ride.status == RideStatus.completed) {
    List<GalleryPhotoCandidate> candidates = const [];
    try {
      candidates = await scanRideGalleryPhotos(
        rideStart: ride.startedAt,
        rideEnd: ride.endedAt ?? DateTime.now(),
        points: points,
      );
    } catch (_) {}
    if (!context.mounted) return;
    if (candidates.isNotEmpty) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RidePhotoImportSheet(
            rideId: rideId,
            rodadaId: linked!.rodadaId,
            cloudRideId: linked.cloudRideId,
            candidates: candidates,
          ),
        ),
      );
    }
    try {
      await ref.read(ridePhotoStoreProvider).uploadPending(
            rideId: rideId,
            rodadaId: linked.rodadaId,
            cloudRideId: linked.cloudRideId,
          );
    } catch (_) {}
  }

  if (!context.mounted) return;
  _openAfterRide(
    context,
    ReelComposeScreen(
      rideId: rideId,
      rodadaId: linked.rodadaId,
    ),
    replaceCurrent: replaceCurrent,
  );
}

void _openAfterRide(
  BuildContext context,
  Widget page, {
  required bool replaceCurrent,
}) {
  final route = MaterialPageRoute<void>(builder: (_) => page);
  if (replaceCurrent) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}
