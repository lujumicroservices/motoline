import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../rodada_providers.dart';
import 'ride_photo_capture.dart';
import 'ride_photo_gallery_scan.dart';

/// Confirm gallery photos before they hit the rodada album.
class RidePhotoImportSheet extends ConsumerStatefulWidget {
  const RidePhotoImportSheet({
    super.key,
    required this.rideId,
    required this.rodadaId,
    required this.candidates,
    this.cloudRideId,
  });

  final String rideId;
  final String rodadaId;
  final String? cloudRideId;
  final List<GalleryPhotoCandidate> candidates;

  @override
  ConsumerState<RidePhotoImportSheet> createState() =>
      _RidePhotoImportSheetState();
}

class _RidePhotoImportSheetState extends ConsumerState<RidePhotoImportSheet> {
  late List<GalleryPhotoCandidate> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = widget.candidates;
  }

  int get _selectedCount => _items.where((c) => c.selected).length;

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    final store = ref.read(ridePhotoStoreProvider);
    try {
      for (final c in _items.where((c) => c.selected)) {
        final bytes = await loadGalleryBytes(c.asset);
        if (bytes == null) continue;
        await store.saveCaptured(
          rideId: widget.rideId,
          bytes: bytes,
          source: 'gallery',
          rodadaId: widget.rodadaId,
          cloudRideId: widget.cloudRideId,
          takenAt: c.takenAt,
          latitude: c.latitude,
          longitude: c.longitude,
        );
      }
      ref.invalidate(rodadaPhotosProvider(widget.rodadaId));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(l10n.photoImportTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.photoImportSkip),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              l10n.photoImportHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final c = _items[i];
                return GestureDetector(
                  onTap: _busy
                      ? null
                      : () => setState(() => c.selected = !c.selected),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: c.thumb == null
                            ? Container(color: AppTheme.asphaltElevated)
                            : Image.memory(c.thumb!, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(
                          c.selected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: c.selected ? AppTheme.line : AppTheme.mist,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _busy || _selectedCount == 0 ? null : _import,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.photoImportConfirm(_selectedCount)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
