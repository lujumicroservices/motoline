import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../rodadas/photos/ride_photo_capture.dart';
import '../rodadas/rodada_providers.dart';
import 'reel_composer.dart';
import 'reel_pauses.dart';
import 'reel_prefs.dart';
import 'reel_preview_screen.dart';
import 'reel_timeline.dart';

class ReelComposeScreen extends ConsumerStatefulWidget {
  const ReelComposeScreen({
    super.key,
    required this.rideId,
    required this.rodadaId,
    this.replaceWithRideDetail = true,
  });

  final String rideId;
  final String rodadaId;
  final bool replaceWithRideDetail;

  @override
  ConsumerState<ReelComposeScreen> createState() => _ReelComposeScreenState();
}

class _ReelComposeScreenState extends ConsumerState<ReelComposeScreen> {
  ReelLength _length = ReelLength.standard;
  List<TrackPoint> _points = [];
  List<DetectedPause> _allPauses = [];
  List<ReelAlbumItem> _album = [];
  List<String> _selectedIds = [];
  bool _loading = true;
  Object? _error;

  List<DetectedPause> get _capped => capPausesForLength(_allPauses, _length);

  ClusteredReelPhotos get _clustered => clusterAlbumToPauses(
        pauses: _capped,
        photos: _album,
      );

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final saved = await loadSavedReelLength();
      await _reload(length: saved, resetSelection: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _reload({
    ReelLength? length,
    bool resetSelection = false,
    String? preferId,
  }) async {
    final db = ref.read(rideDatabaseProvider);
    final rodadas = ref.read(rodadaRepositoryProvider);
    final points = await db.getPoints(widget.rideId);
    final album = await loadReelAlbum(
      db: db,
      rodadas: rodadas,
      rideId: widget.rideId,
      rodadaId: widget.rodadaId,
    );
    final nextLength = length ?? _length;
    final allPauses = detectRidePauses(points);
    final capped = capPausesForLength(allPauses, nextLength);
    final clustered = clusterAlbumToPauses(pauses: capped, photos: album);
    final existing = album.map((p) => p.id).toSet();
    var selected = resetSelection
        ? defaultSelectedPhotoIds(
            clustered: clustered,
            maxPhotos: nextLength.maxPhotos,
          )
        : nextLength.capPhotos(
            _selectedIds.where(existing.contains).toList(),
          );
    if (preferId != null && existing.contains(preferId)) {
      if (!selected.contains(preferId)) {
        if (selected.length < nextLength.maxPhotos) {
          selected = [...selected, preferId];
        } else if (selected.isNotEmpty) {
          selected = [...selected.take(nextLength.maxPhotos - 1), preferId];
        } else {
          selected = [preferId];
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _length = nextLength;
      _points = points;
      _allPauses = allPauses;
      _album = album;
      _selectedIds = selected;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _setLength(ReelLength length) async {
    setState(() => _length = length);
    await saveReelLength(length);
    if (!mounted) return;
    setState(() {
      _selectedIds = length.capPhotos(_selectedIds);
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds = [..._selectedIds]..remove(id);
      } else if (_selectedIds.length < _length.maxPhotos) {
        _selectedIds = [..._selectedIds, id];
      }
    });
  }

  void _generate() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReelPreviewScreen(
          rideId: widget.rideId,
          rodadaId: widget.rodadaId,
          length: _length,
          pauses: _capped,
          selectedPhotoIds: _selectedIds,
          replaceWithRideDetail: widget.replaceWithRideDetail,
        ),
      ),
    );
  }

  Future<void> _addPhoto({DetectedPause? pause}) async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.asphaltElevated,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.photoTake),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.photoAdd),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    final saved = await pickAndSaveRidePhoto(
      context: context,
      ref: ref,
      source: source,
      localRideId: widget.rideId,
      rodadaId: widget.rodadaId,
      fallbackLat: pause?.latitude,
      fallbackLng: pause?.longitude,
    );
    if (saved == null) return;
    await _reload(preferId: 'local:${saved.id}');
  }

  String _labelFor(AppLocalizations l10n, ReelLength length) {
    return switch (length) {
      ReelLength.short => l10n.reelLengthShort,
      ReelLength.standard => l10n.reelLengthStandard,
      ReelLength.long => l10n.reelLengthLong,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(l10n.reelTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          Text(
                            l10n.reelLengthHint,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<ReelLength>(
                            showSelectedIcon: false,
                            segments: [
                              for (final length in ReelLength.values)
                                ButtonSegment(
                                  value: length,
                                  label: Text(
                                    l10n.reelLengthSeconds(
                                      length.totalSec.round(),
                                    ),
                                  ),
                                  tooltip: _labelFor(l10n, length),
                                ),
                            ],
                            selected: {_length},
                            onSelectionChanged: (set) {
                              if (set.isEmpty) return;
                              unawaited(_setLength(set.first));
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.standard,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _labelFor(l10n, _length),
                            style: GoogleFonts.exo2(
                              color: AppTheme.mist,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.reelLengthCap(
                              _length.maxPauseChapters,
                              _length.maxPhotos,
                            ),
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 13,
                            ),
                          ),
                          if (_points.length >= 2) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _ComposeTrailMap(
                                  points: _points,
                                  pauses: _capped,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (_capped.isEmpty)
                            Text(
                              l10n.reelNoStops,
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.steel,
                                fontSize: 14,
                              ),
                            )
                          else
                            for (var i = 0; i < _capped.length; i++)
                              _StopSection(
                                title:
                                    '${l10n.reelStopLabel(_capped[i].index)} · ${formatPauseDuration(_capped[i].duration)}',
                                photos: _clustered.photosByPause[i],
                                selectedIds: _selectedIds,
                                onToggle: _toggle,
                                onAdd: () => _addPhoto(pause: _capped[i]),
                                addLabel: l10n.reelAddToStop,
                                countLabel: l10n.reelPhotoCount,
                              ),
                          if (_clustered.onRoute.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _StopSection(
                              title: l10n.reelOnRoute,
                              photos: _clustered.onRoute,
                              selectedIds: _selectedIds,
                              onToggle: _toggle,
                              onAdd: () => _addPhoto(),
                              addLabel: l10n.reelAddToStop,
                              countLabel: l10n.reelPhotoCount,
                            ),
                          ] else if (_capped.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _addPhoto(),
                                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                                label: Text(l10n.reelAddToStop),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _generate,
                            icon: const Icon(Icons.movie_creation_outlined),
                            label: Text(l10n.reelGenerate),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _StopSection extends StatelessWidget {
  const _StopSection({
    required this.title,
    required this.photos,
    required this.selectedIds,
    required this.onToggle,
    required this.onAdd,
    required this.addLabel,
    required this.countLabel,
  });

  final String title;
  final List<ReelAlbumItem> photos;
  final List<String> selectedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;
  final String addLabel;
  final String Function(int count) countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.exo2(
                    color: AppTheme.mist,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                countLabel(photos.length),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final photo in photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PhotoPickThumb(
                      photo: photo,
                      selected: selectedIds.contains(photo.id),
                      onTap: () => onToggle(photo.id),
                    ),
                  ),
                _AddTile(label: addLabel, onTap: onAdd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPickThumb extends StatelessWidget {
  const _PhotoPickThumb({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final ReelAlbumItem photo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = photo.localPath;
    final hasFile = path != null && File(path).existsSync();
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 84,
              height: 84,
              child: hasFile
                  ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 168)
                  : Container(
                      color: AppTheme.asphaltElevated,
                      child: const Icon(Icons.image_outlined, color: AppTheme.steel),
                    ),
            ),
          ),
          if (selected)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.line,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.check, size: 14, color: AppTheme.asphalt),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined, color: AppTheme.mist, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeTrailMap extends StatelessWidget {
  const _ComposeTrailMap({
    required this.points,
    required this.pauses,
  });

  final List<TrackPoint> points;
  final List<DetectedPause> pauses;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.asphaltElevated,
      child: CustomPaint(
        painter: _TrailPainter(points: points, pauses: pauses),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.pauses});

  final List<TrackPoint> points;
  final List<DetectedPause> pauses;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final sampled = _downsample(points, 160);
    var minLat = sampled.first.latitude;
    var maxLat = sampled.first.latitude;
    var minLng = sampled.first.longitude;
    var maxLng = sampled.first.longitude;
    for (final p in sampled) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    if ((maxLng - minLng).abs() < 0.0008) {
      minLng -= 0.004;
      maxLng += 0.004;
    }
    if ((maxLat - minLat).abs() < 0.0008) {
      minLat -= 0.004;
      maxLat += 0.004;
    }
    const pad = 18.0;
    Offset project(double lat, double lng) {
      final dx = maxLng == minLng ? 0.5 : (lng - minLng) / (maxLng - minLng);
      final dy = maxLat == minLat ? 0.5 : (lat - minLat) / (maxLat - minLat);
      return Offset(pad + dx * (size.width - pad * 2), size.height - pad - dy * (size.height - pad * 2));
    }

    final paint = Paint()
      ..color = AppTheme.line
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 1; i < sampled.length; i++) {
      canvas.drawLine(
        project(sampled[i - 1].latitude, sampled[i - 1].longitude),
        project(sampled[i].latitude, sampled[i].longitude),
        paint,
      );
    }
    for (final pause in pauses) {
      final o = project(pause.latitude, pause.longitude);
      canvas.drawCircle(o, 8, Paint()..color = AppTheme.lineHot);
      canvas.drawCircle(o, 3.5, Paint()..color = AppTheme.asphalt);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.pauses != pauses;
  }
}

List<TrackPoint> _downsample(List<TrackPoint> points, int maxPoints) {
  if (points.length <= maxPoints) return points;
  final step = points.length / maxPoints;
  return [
    for (var i = 0; i < maxPoints; i++)
      points[(i * step).floor().clamp(0, points.length - 1)],
  ];
}
