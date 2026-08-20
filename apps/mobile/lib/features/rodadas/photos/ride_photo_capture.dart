import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/track_point.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../rodada_providers.dart';
import 'ride_photo_store.dart';

final ridePhotoStoreProvider = Provider<RidePhotoStore>((ref) {
  return RidePhotoStore(
    db: ref.watch(rideDatabaseProvider),
    rodadas: ref.watch(rodadaRepositoryProvider),
  );
});

/// One-tap camera that geotags with the latest track point / live GPS.
Future<void> captureRidePhoto({
  required BuildContext context,
  required WidgetRef ref, required String? localRideId,
  String? rodadaId,
  TrackPoint? lastPoint,
  double? fallbackLat,
  double? fallbackLng,
}) async {
  final l10n = context.l10n;
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final takenAt = DateTime.now();

    var rideId = localRideId;
    final db = ref.read(rideDatabaseProvider);
    if (rideId == null) {
      final active = await db.getActiveRide();
      rideId = active?.id;
    }
    if (rideId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photoNeedsActiveRide)),
      );
      return;
    }

    var lat = lastPoint?.latitude ?? fallbackLat;
    var lng = lastPoint?.longitude ?? fallbackLng;
    if (lat == null || lng == null) {
      final points = await db.getPoints(rideId);
      final last = lastTrackPoint(points);
      lat ??= last?.latitude;
      lng ??= last?.longitude;
    }

    String? cloudRideId;
    String? attachRodada = rodadaId;
    try {
      final repo = ref.read(rodadaRepositoryProvider);
      attachRodada ??= (await repo.findAttachableRodada())?.id;
      cloudRideId = await repo.cloudRideIdForLocal(rideId);
    } catch (_) {}

    await ref.read(ridePhotoStoreProvider).saveCaptured(
          rideId: rideId,
          bytes: bytes,
          source: 'camera',
          rodadaId: attachRodada,
          cloudRideId: cloudRideId,
          takenAt: takenAt,
          latitude: lat,
          longitude: lng,
        );
    if (attachRodada != null) {
      ref.invalidate(rodadaPhotosProvider(attachRodada));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.photoLinkedToRoute)),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

class RidePhotoShutterButton extends ConsumerWidget {
  const RidePhotoShutterButton({
    super.key,
    this.localRideId,
    this.rodadaId,
    this.lastPoint,
    this.fallbackLat,
    this.fallbackLng,
    this.compact = false,
  });

  final String? localRideId;
  final String? rodadaId;
  final TrackPoint? lastPoint;
  final double? fallbackLat;
  final double? fallbackLng;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (compact) {
      return IconButton(
        tooltip: l10n.photoCaptureTooltip,
        icon: const Icon(Icons.photo_camera_outlined),
        color: AppTheme.mist,
        onPressed: () => captureRidePhoto(
          context: context,
          ref: ref,
          localRideId: localRideId,
          rodadaId: rodadaId,
          lastPoint: lastPoint,
          fallbackLat: fallbackLat,
          fallbackLng: fallbackLng,
        ),
      );
    }
    return FloatingActionButton(
      heroTag: 'ride-photo-shutter',
      backgroundColor: AppTheme.asphaltElevated,
      foregroundColor: AppTheme.mist,
      onPressed: () => captureRidePhoto(
        context: context,
        ref: ref,
        localRideId: localRideId,
        rodadaId: rodadaId,
        lastPoint: lastPoint,
        fallbackLat: fallbackLat,
        fallbackLng: fallbackLng,
      ),
      child: const Icon(Icons.photo_camera_outlined),
    );
  }
}
