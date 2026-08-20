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
import 'reel_timeline.dart';

const reelWidth = 720;
const reelHeight = 1280;
const reelFps = 12;

class ReelRenderResult {
  const ReelRenderResult({
    required this.highlights,
    this.videoPath,
    this.imagePath,
  });

  final ReelHighlights highlights;
  final String? videoPath;
  final String? imagePath;

  String get sharePath => videoPath ?? imagePath!;
  bool get isVideo => videoPath != null;
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
    final photos = await _loadPhotos(rideId: rideId, rodadaId: rodadaId);

    final highlights = buildReelHighlights(
      analytics: analytics,
      title: ride.displayTitle(),
      destination: rodada?.destination ?? rodada?.title,
      riderCount: members.isEmpty ? 1 : members.length,
      photos: photos,
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

    final images = <ui.Image>[];
    for (final photo in highlights.photos) {
      images.add(await decodeUiImage(photo.bytes, targetWidth: reelWidth));
    }

    final painter = ReelFramePainter(
      highlights: highlights,
      copy: copy,
      photos: images,
    );
    final timeline = painter.timeline;
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

    for (final img in images) {
      img.dispose();
    }

    return ReelRenderResult(
      highlights: highlights,
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

  Future<List<ReelPhoto>> _loadPhotos({
    required String rideId,
    required String rodadaId,
  }) async {
    final out = <ReelPhoto>[];
    final local = await db.getRidePhotos(rideId);
    for (final p in local) {
      final path = p.localPath;
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      out.add(
        ReelPhoto(
          bytes: await file.readAsBytes(),
          latitude: p.latitude,
          longitude: p.longitude,
          takenAt: p.takenAt,
        ),
      );
      if (out.length >= 3) return out;
    }
    try {
      final cloud = await rodadas.listPhotos(rodadaId, limit: 24);
      for (final p in cloud) {
        if (out.length >= 3) break;
        try {
          final url = await rodadas.signedPhotoUrl(p.storagePath);
          final client = HttpClient();
          try {
            final req = await client.getUrl(Uri.parse(url));
            final res = await req.close();
            final bytes = await res.fold<List<int>>(
              <int>[],
              (prev, chunk) => prev..addAll(chunk),
            );
            out.add(
              ReelPhoto(
                bytes: Uint8List.fromList(bytes),
                latitude: p.latitude,
                longitude: p.longitude,
                takenAt: p.takenAt ?? p.createdAt,
              ),
            );
          } finally {
            client.close(force: true);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }
}

ReelComposer reelComposerFor({
  required RideDatabase db,
  required RodadaRepository rodadas,
}) =>
    ReelComposer(db: db, rodadas: rodadas);
