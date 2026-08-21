import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/ride_photo.dart';
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
  required WidgetRef ref,
  required String? localRideId,
  String? rodadaId,
  TrackPoint? lastPoint,
  double? fallbackLat,
  double? fallbackLng,
}) async {
  await pickAndSaveRidePhoto(
    context: context,
    ref: ref,
    source: ImageSource.camera,
    localRideId: localRideId,
    rodadaId: rodadaId,
    lastPoint: lastPoint,
    fallbackLat: fallbackLat,
    fallbackLng: fallbackLng,
  );
}

/// Camera or gallery → local album + rodada upload. [fallbackLat]/[fallbackLng]
/// pin the photo when EXIF is missing (e.g. adding from a reel stop).
Future<RidePhoto?> pickAndSaveRidePhoto({
  required BuildContext context,
  required WidgetRef ref,
  required ImageSource source,
  required String? localRideId,
  String? rodadaId,
  TrackPoint? lastPoint,
  double? fallbackLat,
  double? fallbackLng,
  DateTime? takenAt,
  bool showSnackbars = true,
}) async {
  final l10n = context.l10n;
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 82,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final at = takenAt ?? DateTime.now();

    var rideId = localRideId;
    final db = ref.read(rideDatabaseProvider);
    if (rideId == null) {
      final active = await db.getActiveRide();
      rideId = active?.id;
    }
    if (rideId == null) {
      if (!context.mounted) return null;
      if (showSnackbars) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.photoNeedsActiveRide)),
        );
      }
      return null;
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

    final saved = await ref.read(ridePhotoStoreProvider).saveCaptured(
          rideId: rideId,
          bytes: bytes,
          source: source == ImageSource.camera ? 'camera' : 'gallery',
          rodadaId: attachRodada,
          cloudRideId: cloudRideId,
          takenAt: at,
          latitude: lat,
          longitude: lng,
        );
    if (attachRodada != null) {
      ref.invalidate(rodadaPhotosProvider(attachRodada));
    }
    if (!context.mounted) return saved;
    if (showSnackbars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.photoLinkedToRoute)),
      );
    }
    return saved;
  } catch (e) {
    if (!context.mounted) return null;
    if (showSnackbars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
    return null;
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
