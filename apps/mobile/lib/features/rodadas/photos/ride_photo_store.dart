import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/ride_database.dart';
import '../../../core/models/ride_photo.dart';
import '../../../core/models/track_point.dart';
import '../rodada_repository.dart';

class RidePhotoStore {
  RidePhotoStore({
    required RideDatabase db,
    required RodadaRepository rodadas,
  })  : _db = db,
        _rodadas = rodadas;

  final RideDatabase _db;
  final RodadaRepository _rodadas;
  final _uuid = const Uuid();

  Future<RidePhoto> saveCaptured({
    required String rideId,
    required Uint8List bytes,
    required String source,
    String? rodadaId,
    String? cloudRideId,
    DateTime? takenAt,
    double? latitude,
    double? longitude,
  }) async {
    final prepared = await prepareAlbumImage(bytes);
    final hash = sha256.convert(prepared.bytes).toString();
    if (await _db.ridePhotoHashExists(hash)) {
      final existing = (await _db.getRidePhotos(rideId))
          .where((p) => p.contentHash == hash)
          .toList();
      if (existing.isNotEmpty) return existing.first;
    }

    final dir = await _photoDir(rideId);
    final file = File(p.join(dir.path, '$hash.${prepared.ext}'));
    await file.writeAsBytes(prepared.bytes, flush: true);

    final photo = RidePhoto(
      id: _uuid.v4(),
      rideId: rideId,
      rodadaId: rodadaId,
      localPath: file.path,
      takenAt: takenAt ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      source: source,
      contentHash: hash,
      createdAt: DateTime.now(),
    );
    await _db.upsertRidePhoto(photo);

    if (rodadaId != null) {
      try {
        final uploaded = await _rodadas.uploadPhoto(
          rodadaId: rodadaId,
          bytes: prepared.bytes,
          contentType: prepared.mime,
          latitude: latitude,
          longitude: longitude,
          takenAt: photo.takenAt,
          rideId: cloudRideId,
          source: source,
          contentHash: hash,
        );
        await _db.markRidePhotoUploaded(
          id: photo.id,
          storagePath: uploaded.storagePath,
          rodadaId: rodadaId,
        );
        return photo.copyWith(
          storagePath: uploaded.storagePath,
          uploaded: true,
          rodadaId: rodadaId,
        );
      } catch (e) {
        // Local file stays queued; caller must not treat this as linked.
        rethrow;
      }
    }
    return photo;
  }

  Future<int> uploadPending({
    required String rideId,
    required String rodadaId,
    String? cloudRideId,
  }) async {
    await _db.setRidePhotosRodada(rideId: rideId, rodadaId: rodadaId);
    final pending = await _db.getPendingRidePhotos(rideId: rideId);
    var ok = 0;
    for (final photo in pending) {
      final path = photo.localPath;
      if (path == null) continue;
      final file = File(path);
      if (!file.existsSync()) continue;
      try {
        final bytes = await file.readAsBytes();
        final mime = _mimeFor(file.path, bytes);
        final uploaded = await _rodadas.uploadPhoto(
          rodadaId: rodadaId,
          bytes: bytes,
          contentType: mime,
          latitude: photo.latitude,
          longitude: photo.longitude,
          takenAt: photo.takenAt,
          rideId: cloudRideId,
          source: photo.source,
          contentHash: photo.contentHash,
        );
        await _db.markRidePhotoUploaded(
          id: photo.id,
          storagePath: uploaded.storagePath,
          rodadaId: rodadaId,
        );
        ok++;
      } catch (_) {}
    }
    return ok;
  }

  Future<Directory> _photoDir(String rideId) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'ride_photos', rideId));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

class AlbumImage {
  const AlbumImage({
    required this.bytes,
    required this.mime,
    required this.ext,
  });

  final Uint8List bytes;
  final String mime;
  final String ext;
}

Future<AlbumImage> prepareAlbumImage(Uint8List bytes, {int maxEdge = 1920}) async {
  if (bytes.lengthInBytes < 1800000 && _looksJpeg(bytes)) {
    return AlbumImage(bytes: bytes, mime: 'image/jpeg', ext: 'jpg');
  }
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxEdge);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    if (data == null) {
      return AlbumImage(
        bytes: bytes,
        mime: _looksJpeg(bytes) ? 'image/jpeg' : 'image/png',
        ext: _looksJpeg(bytes) ? 'jpg' : 'png',
      );
    }
    return AlbumImage(
      bytes: data.buffer.asUint8List(),
      mime: 'image/png',
      ext: 'png',
    );
  } catch (_) {
    return AlbumImage(
      bytes: bytes,
      mime: _looksJpeg(bytes) ? 'image/jpeg' : 'image/png',
      ext: _looksJpeg(bytes) ? 'jpg' : 'png',
    );
  }
}

bool _looksJpeg(Uint8List bytes) =>
    bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;

String _mimeFor(String path, Uint8List bytes) {
  if (path.toLowerCase().endsWith('.png')) return 'image/png';
  if (path.toLowerCase().endsWith('.webp')) return 'image/webp';
  if (_looksJpeg(bytes)) return 'image/jpeg';
  return 'image/jpeg';
}

TrackPoint? lastTrackPoint(List<TrackPoint> points) {
  if (points.isEmpty) return null;
  return points.last;
}
