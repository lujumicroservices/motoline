import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../theme/app_theme.dart';
import '../models/rodada_models.dart';
import '../rodada_providers.dart';

class RodadaPhotosTab extends ConsumerWidget {
  const RodadaPhotosTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(rodadaPhotosProvider(rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Album loads thumbs only. Full image opens on tap and frees when closed.',
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _pickAndUpload(context, ref),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: photos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No photos yet'));
              }
              return GridView.builder(
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
      ],
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      await ref.read(rodadaRepositoryProvider).uploadPhoto(
            rodadaId: rodadaId,
            bytes: bytes,
            contentType: mime,
          );
      ref.invalidate(rodadaPhotosProvider(rodadaId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
    final url = ref.watch(rodadaPhotoUrlProvider(photo.storagePath));
    return Scaffold(
      appBar: AppBar(
        title: Text(photo.displayName ?? 'Photo'),
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
