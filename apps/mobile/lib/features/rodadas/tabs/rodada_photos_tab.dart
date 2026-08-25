import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/ride.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../../reel/reel_compose_screen.dart';
import '../models/rodada_models.dart';
import '../photos/ride_photo_capture.dart';
import '../photos/ride_photo_gallery_scan.dart';
import '../photos/ride_photo_import_sheet.dart';
import '../rodada_providers.dart';

class RodadaPhotosTab extends ConsumerWidget {
  const RodadaPhotosTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final photos = ref.watch(rodadaPhotosProvider(rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.photosAlbumHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => captureRidePhoto(
                      context: context,
                      ref: ref,
                      localRideId: null,
                      rodadaId: rodadaId,
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(l10n.photoTake),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _pickAndUpload(context, ref),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(l10n.photoAdd),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _importFromRoll(context, ref),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l10n.photoImportFromRoll),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openReel(context, ref),
                    icon: const Icon(Icons.movie_creation_outlined, size: 18),
                    label: Text(l10n.reelGenerate),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(rodadaPhotosProvider(rodadaId));
              await ref.read(rodadaPhotosProvider(rodadaId).future);
            },
            child: photos.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [Text('$e')],
              ),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(l10n.noPhotosYet)),
                    ],
                  );
                }
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final photo = list[i];
                  return _PhotoThumb(
                    photo: photo,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PhotoViewer(photo: photo),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 82,
    );
    if (files.isEmpty) return;
    if (!context.mounted) return;
    await _uploadPickedFiles(context, ref, files);
  }

  Future<void> _uploadPickedFiles(
    BuildContext context,
    WidgetRef ref,
    List<XFile> files,
  ) async {
    final l10n = context.l10n;
    try {
      var ok = 0;
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final mime = file.mimeType ?? 'image/jpeg';
        await ref.read(rodadaRepositoryProvider).uploadPhoto(
              rodadaId: rodadaId,
              bytes: bytes,
              contentType: mime,
              source: 'gallery',
              takenAt: DateTime.now(),
            );
        ok++;
      }
      ref.invalidate(rodadaPhotosProvider(rodadaId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok == 1 ? l10n.photoUploaded : l10n.photosUploaded(ok),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<String?> _localRideId(WidgetRef ref) async {
    final repo = ref.read(rodadaRepositoryProvider);
    final me = repo.currentUserId;
    final rides = await ref.read(rodadaRidesProvider(rodadaId).future);
    final mine = rides.where((r) => me == null || r.userId == me).toList();
    if (mine.isNotEmpty && mine.first.localId.isNotEmpty) {
      return mine.first.localId;
    }
    final local = await ref.read(ridesListProvider.future);
    final completed =
        local.where((r) => r.status == RideStatus.completed).toList();
    return completed.isEmpty ? null : completed.first.id;
  }

  Future<void> _importFromRoll(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final rideId = await _localRideId(ref);
      if (rideId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noCompletedRidesToLink)),
        );
        return;
      }
      final ride = await ref.read(rideDatabaseProvider).getRide(rideId);
      final points = await ref.read(rideDatabaseProvider).getPoints(rideId);
      if (ride == null) return;
      final candidates = await scanRideGalleryPhotos(
        rideStart: ride.startedAt,
        rideEnd: ride.endedAt ?? DateTime.now(),
        points: points,
      );
      if (!context.mounted) return;
      if (candidates.isEmpty) {
        if (!context.mounted) return;
        final files = await ImagePicker().pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 82,
        );
        if (files.isEmpty || !context.mounted) return;
        await _uploadPickedFiles(context, ref, files);
        return;
      }
      final cloudId = await ref
          .read(rodadaRepositoryProvider)
          .cloudRideIdForLocal(rideId);
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RidePhotoImportSheet(
            rideId: rideId,
            rodadaId: rodadaId,
            cloudRideId: cloudId,
            candidates: candidates,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openReel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final rideId = await _localRideId(ref);
      if (rideId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noCompletedRidesToLink)),
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReelComposeScreen(
            rideId: rideId,
            rodadaId: rodadaId,
            replaceWithRideDetail: false,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _PhotoThumb extends ConsumerWidget {
  const _PhotoThumb({required this.photo, required this.onTap});

  final RodadaPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(rodadaPhotoUrlProvider(photo.storagePath));
    return InkWell(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url.when(
          loading: () => Container(color: AppTheme.asphaltElevated),
          error: (_, __) => Container(
            color: AppTheme.asphaltElevated,
            child: const Icon(Icons.broken_image),
          ),
          data: (u) => Image.network(
            u,
            fit: BoxFit.cover,
            // Prefer low RAM for grid.
            cacheWidth: 256,
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends ConsumerWidget {
  const _PhotoViewer({required this.photo});

  final RodadaPhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final url = ref.watch(rodadaPhotoUrlProvider(photo.storagePath));
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.displayName ?? l10n.photoTitle),
      ),
      body: url.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (u) => InteractiveViewer(
          child: Center(
            child: Image.network(u, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
