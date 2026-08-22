import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/ride_photo.dart';
import '../../../core/models/track_point.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../models/rodada_models.dart';
import '../rodada_providers.dart';
import 'ride_photo_store.dart';

final ridePhotoStoreProvider = Provider<RidePhotoStore>((ref) {
  return RidePhotoStore(
    db: ref.watch(rideDatabaseProvider),
    rodadas: ref.watch(rodadaRepositoryProvider),
  );
});

/// Ride id → rodada id for the recording you opened a rodada camera on.
class RecordingRodadaBinding extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void bind({required String rideId, required String rodadaId}) {
    final id = rodadaId.trim();
    if (rideId.isEmpty || id.isEmpty) return;
    if (state[rideId] == id) return;
    state = {...state, rideId: id};
  }

  String? rodadaFor(String rideId) => state[rideId];
}

final recordingRodadaBindingProvider =
    NotifierProvider<RecordingRodadaBinding, Map<String, String>>(
  RecordingRodadaBinding.new,
);

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

    final attachRodada = await _resolveCaptureRodada(
      ref,
      explicitRodadaId: rodadaId,
      localRideId: rideId,
    );
    if (rideId != null && attachRodada != null) {
      ref.read(recordingRodadaBindingProvider.notifier).bind(
            rideId: rideId,
            rodadaId: attachRodada,
          );
    }

    if (rideId == null) {
      if (attachRodada != null) {
        final prepared = await prepareAlbumImage(bytes);
        await ref.read(rodadaRepositoryProvider).uploadPhoto(
              rodadaId: attachRodada,
              bytes: prepared.bytes,
              contentType: prepared.mime,
              latitude: fallbackLat,
              longitude: fallbackLng,
              takenAt: at,
              source: source == ImageSource.camera ? 'camera' : 'gallery',
            );
        ref.invalidate(rodadaPhotosProvider(attachRodada));
        if (!context.mounted) return null;
        if (showSnackbars) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.photoUploaded)),
          );
        }
        return null;
      }
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
    try {
      cloudRideId =
          await ref.read(rodadaRepositoryProvider).cloudRideIdForLocal(rideId);
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
        SnackBar(
          content: Text(
            attachRodada != null
                ? l10n.photoUploaded
                : l10n.photoLinkedToRoute,
          ),
        ),
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

Future<String?> _resolveCaptureRodada(
  WidgetRef ref, {
  String? explicitRodadaId,
  String? localRideId,
}) async {
  String? stamped;
  String? linked;
  if (localRideId != null && localRideId.isNotEmpty) {
    stamped = await ref.read(rideDatabaseProvider).rodadaIdForRide(localRideId);
    try {
      linked = await ref
          .read(rodadaRepositoryProvider)
          .linkedRodadaIdForLocal(localRideId);
    } catch (_) {}
  }
  return resolveCaptureRodadaId(
    explicitRodadaId: explicitRodadaId,
    boundRodadaId: localRideId == null
        ? null
        : ref.read(recordingRodadaBindingProvider.notifier).rodadaFor(localRideId),
    stampedRodadaId: stamped,
    cloudLinkedRodadaId: linked,
  );
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
    final explicit = rodadaId?.trim();
    final hasExplicit = explicit != null && explicit.isNotEmpty;
    final activeRideId = localRideId ??
        ref.watch(activeRideProvider).asData?.value?.ride.id;
    if (hasExplicit && activeRideId != null) {
      final bound = ref.read(recordingRodadaBindingProvider)[activeRideId];
      if (bound != explicit) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(recordingRodadaBindingProvider.notifier).bind(
                rideId: activeRideId,
                rodadaId: explicit,
              );
        });
      }
    }
    final dest = hasExplicit
        ? explicit
        : (activeRideId == null
            ? null
            : ref.watch(recordingRodadaBindingProvider)[activeRideId]);

    void shoot() => captureRidePhoto(
          context: context,
          ref: ref,
          localRideId: localRideId ?? activeRideId,
          rodadaId: dest,
          lastPoint: lastPoint,
          fallbackLat: fallbackLat,
          fallbackLng: fallbackLng,
        );

    if (compact) {
      return IconButton(
        tooltip: l10n.photoCaptureTooltip,
        icon: const Icon(Icons.photo_camera_outlined),
        color: AppTheme.mist,
        onPressed: shoot,
      );
    }
    return FloatingActionButton(
      heroTag: 'ride-photo-shutter',
      backgroundColor: AppTheme.asphaltElevated,
      foregroundColor: AppTheme.mist,
      onPressed: shoot,
      child: const Icon(Icons.photo_camera_outlined),
    );
  }
}
