import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/db/ride_database.dart';
import '../../l10n/app_localizations.dart';
import '../rodadas/rodada_repository.dart';
import 'reel_encoder.dart';
import 'reel_highlights.dart';
import 'reel_painter.dart';
import 'reel_pauses.dart';
import 'reel_timeline.dart';

const reelWidth = 720;
const reelHeight = 1280;
const reelFps = 12;

class ReelRenderResult {
  const ReelRenderResult({
    required this.highlights,
    required this.totalSec,
    this.videoPath,
    this.imagePath,
  });

  final ReelHighlights highlights;
  final double totalSec;
  final String? videoPath;
  final String? imagePath;

  String get sharePath => videoPath ?? imagePath!;
  bool get isVideo => videoPath != null;
  int get durationMs => (totalSec * 1000).round();
}

class ReelComposer {
  ReelComposer({
    required this.db,
    required this.rodadas,
  });

  final RideDatabase db;
  final RodadaRepository rodadas;

  Future<ReelRenderResult> render({
    required String rideId,
    required String rodadaId,
    required AppLocalizations l10n,
    ReelLength length = ReelLength.standard,
    List<DetectedPause>? pauses,
    List<String>? selectedPhotoIds,
    void Function(double progress)? onProgress,
  }) async {
    final ride = await db.getRide(rideId);
    if (ride == null) {
      throw StateError('Ride not found');
    }
    final points = await db.getPoints(rideId);
    final lean = await db.getLeanSamples(rideId);
    final analytics = RideAnalytics(
      ride: ride,
      points: points,
      leanSamples: lean,
    );
    final rodada = await rodadas.getRodada(rodadaId);
    final members = await rodadas.listMembers(rodadaId);
    final album = await loadReelAlbum(
      db: db,
      rodadas: rodadas,
      rideId: rideId,
      rodadaId: rodadaId,
    );
    final cappedPauses = capPausesForLength(
      pauses ?? detectRidePauses(points),
      length,
    );
    final clustered = clusterAlbumToPauses(
      pauses: cappedPauses,
      photos: album,
    );
    final selectedIds = length.capPhotos(
      selectedPhotoIds ??
          defaultSelectedPhotoIds(
            clustered: clustered,
            maxPhotos: length.maxPhotos,
          ),
    );
    final selectedSet = selectedIds.toSet();

    final pauseModels = <ReelPause>[];
    for (var i = 0; i < cappedPauses.length; i++) {
      final pause = cappedPauses[i];
      final photos = <ReelPhoto>[];
      for (final item in clustered.photosByPause[i]) {
        if (!selectedSet.contains(item.id)) continue;
        if (photos.length >= 3) continue;
        final photo = await _toReelPhoto(item);
        if (photo != null) photos.add(photo);
      }
      pauseModels.add(
        ReelPause(
          index: pause.index,
          latitude: pause.latitude,
          longitude: pause.longitude,
          startedAt: pause.startedAt,
          endedAt: pause.endedAt,
          label:
              '${l10n.reelStopLabel(pause.index)} · ${formatPauseDuration(pause.duration)}',
          photos: photos,
        ),
      );
    }
    final onRoute = <ReelPhoto>[];
    for (final item in clustered.onRoute) {
      if (!selectedSet.contains(item.id)) continue;
      final photo = await _toReelPhoto(item);
      if (photo != null) onRoute.add(photo);
    }

    final hasPhotos =
        pauseModels.any((p) => p.photos.isNotEmpty) || onRoute.isNotEmpty;
    final extraOnRoute =
        pauseModels.isNotEmpty && onRoute.isNotEmpty ? 1 : 0;
    final chapterCount = pauseModels.isNotEmpty
        ? pauseModels.length + extraOnRoute
        : (hasPhotos ? 1 : 0);
    final timeline = ReelTimeline.fromLength(
      length,
      pauseCount: chapterCount,
    );

    final highlights = buildReelHighlights(
      analytics: analytics,
      title: ride.displayTitle(),
      destination: rodada?.destination ?? rodada?.title,
      riderCount: members.isEmpty ? 1 : members.length,
      pauses: pauseModels,
      onRoutePhotos: onRoute,
      maxPhotos: length.maxPhotos,
    );
    final copy = ReelCopy(
      leanLabel: l10n.statPeakLean,
      hookSub: l10n.reelHookSub,
      kmLabel: l10n.statDistance,
      curvesLabel: l10n.reelCurvesLabel,
      ridersLabel: l10n.reelRidersLabel,
      speedLabel: l10n.statTopSpeed,
      endQuestion: l10n.reelEndQuestion,
      cta: l10n.reelCta,
    );

    final pauseImages = <List<ui.Image>>[];
    for (final pause in highlights.pauses) {
      final images = <ui.Image>[];
      for (final photo in pause.photos) {
        images.add(await decodeUiImage(photo.bytes, targetWidth: reelWidth));
      }
      pauseImages.add(images);
    }
    final onRouteImages = <ui.Image>[];
    for (final photo in highlights.onRoutePhotos) {
      onRouteImages.add(await decodeUiImage(photo.bytes, targetWidth: reelWidth));
    }
    final images = <ui.Image>[
      for (final group in pauseImages) ...group,
      ...onRouteImages,
    ];

    final painter = ReelFramePainter(
      highlights: highlights,
      copy: copy,
      photos: images,
      pausePhotos: pauseImages,
      onRoutePhotos: onRouteImages,
      timeline: timeline,
    );
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final pngPath = p.join(dir.path, 'reel_$stamp.png');
    final mp4Path = p.join(dir.path, 'reel_$stamp.mp4');

    final hookImage = await _raster(painter, 0.4);
    final pngBytes = await hookImage.toByteData(format: ui.ImageByteFormat.png);
    hookImage.dispose();
    if (pngBytes != null) {
      await File(pngPath).writeAsBytes(pngBytes.buffer.asUint8List(), flush: true);
    }

    String? videoPath;
    if (ReelEncoder.isSupported) {
      try {
        await ReelEncoder.start(
          outputPath: mp4Path,
          width: reelWidth,
          height: reelHeight,
          fps: reelFps,
        );
        final totalFrames = (timeline.totalSec * reelFps).round();
        const size = Size(720, 1280);
        for (var i = 0; i < totalFrames; i++) {
          final t = i / reelFps;
          final frame = await _raster(painter, t, size: size);
          final rgba = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
          frame.dispose();
          if (rgba == null) continue;
          await ReelEncoder.addRgbaFrame(rgba.buffer.asUint8List());
          onProgress?.call((i + 1) / totalFrames);
        }
        await ReelEncoder.finish();
        if (File(mp4Path).existsSync() && File(mp4Path).lengthSync() > 1000) {
          videoPath = mp4Path;
        }
      } catch (_) {
        try {
          await ReelEncoder.finish();
        } catch (_) {}
      }
    }

    for (final group in pauseImages) {
      for (final img in group) {
        img.dispose();
      }
    }
    for (final img in onRouteImages) {
      img.dispose();
    }

    return ReelRenderResult(
      highlights: highlights,
      totalSec: timeline.totalSec,
      videoPath: videoPath,
      imagePath: File(pngPath).existsSync() ? pngPath : null,
    );
  }

  Future<ui.Image> _raster(
    ReelFramePainter painter,
    double timeSec, {
    Size size = const Size(720, 1280),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    painter.paint(canvas, size, timeSec);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    picture.dispose();
    return image;
  }

  Future<ReelPhoto?> _toReelPhoto(ReelAlbumItem item) async {
    Uint8List? bytes;
    final path = item.localPath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        bytes = await file.readAsBytes();
      }
    }
    if (bytes == null && item.storagePath != null) {
      try {
        final url = await rodadas.signedPhotoUrl(item.storagePath!);
        final client = HttpClient();
        try {
          final req = await client.getUrl(Uri.parse(url));
          final res = await req.close();
          bytes = Uint8List.fromList(
            await res.fold<List<int>>(
              <int>[],
              (prev, chunk) => prev..addAll(chunk),
            ),
          );
        } finally {
          client.close(force: true);
        }
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) return null;
    return ReelPhoto(
      id: item.id,
      bytes: bytes,
      latitude: item.latitude,
      longitude: item.longitude,
      takenAt: item.takenAt,
    );
  }
}

ReelComposer reelComposerFor({
  required RideDatabase db,
  required RodadaRepository rodadas,
}) =>
    ReelComposer(db: db, rodadas: rodadas);

Future<List<ReelAlbumItem>> loadReelAlbum({
  required RideDatabase db,
  required RodadaRepository rodadas,
  required String rideId,
  required String rodadaId,
}) async {
  final out = <ReelAlbumItem>[];
  final seenHash = <String>{};
  final seenPath = <String>{};
  final local = await db.getRidePhotos(rideId);
  for (final p in local) {
    final hash = p.contentHash;
    if (hash != null) seenHash.add(hash);
    final storage = p.storagePath;
    if (storage != null) seenPath.add(storage);
    out.add(
      ReelAlbumItem(
        id: 'local:${p.id}',
        localPath: p.localPath,
        storagePath: p.storagePath,
        takenAt: p.takenAt,
        latitude: p.latitude,
        longitude: p.longitude,
      ),
    );
  }
  try {
    final cloud = await rodadas.listPhotos(rodadaId, limit: 48);
    for (final p in cloud) {
      final hash = p.contentHash;
      if (hash != null && seenHash.contains(hash)) continue;
      if (seenPath.contains(p.storagePath)) continue;
      out.add(
        ReelAlbumItem(
          id: 'cloud:${p.id}',
          storagePath: p.storagePath,
          takenAt: p.takenAt ?? p.createdAt,
          latitude: p.latitude,
          longitude: p.longitude,
        ),
      );
    }
  } catch (_) {}
  return out;
}
