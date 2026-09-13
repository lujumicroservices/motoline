import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../../../core/models/track_point.dart';
import 'ride_photo_matcher.dart';

class GalleryPhotoCandidate {
  GalleryPhotoCandidate({
    required this.asset,
    required this.takenAt,
    required this.match,
    this.thumb,
    this.selected = true,
  });

  final AssetEntity asset;
  final DateTime takenAt;
  final PhotoTrackMatch match;
  Uint8List? thumb;
  bool selected;

  double? get latitude => match.latitude;
  double? get longitude => match.longitude;
}

class GalleryScanResult {
  const GalleryScanResult({
    required this.candidates,
    this.denied = false,
    this.limited = false,
  });

  final List<GalleryPhotoCandidate> candidates;
  final bool denied;
  final bool limited;
}

Future<GalleryScanResult> scanRideGalleryPhotos({
  required DateTime rideStart,
  required DateTime rideEnd,
  required List<TrackPoint> points,
}) async {
  // Play policy: do not request READ_MEDIA_IMAGES/VIDEO. Android uses the
  // system photo picker instead (see ImagePicker.pickMultiImage).
  if (Platform.isAndroid) {
    return const GalleryScanResult(candidates: []);
  }

  final perm = await PhotoManager.requestPermissionExtend(
    requestOption: const PermissionRequestOption(
      iosAccessLevel: IosAccessLevel.readWrite,
      androidPermission: AndroidPermission(
        type: RequestType.image,
        mediaLocation: true,
      ),
    ),
  );
  if (!perm.hasAccess) {
    return const GalleryScanResult(candidates: [], denied: true);
  }

  final from = rideStart.subtract(const Duration(minutes: 30));
  final to = rideEnd.add(const Duration(minutes: 30));
  var assets = await _recentImages(from: from, to: to);
  if (assets.isEmpty) {
    assets = await _recentImages();
  }

  final out = <GalleryPhotoCandidate>[];
  for (final asset in assets) {
    final taken = asset.createDateTime;
    final lat = asset.latitude == 0 ? null : asset.latitude;
    final lng = asset.longitude == 0 ? null : asset.longitude;
    final match = matchPhotoToTrack(
      takenAt: taken,
      photoLat: lat,
      photoLng: lng,
      points: points,
      rideStart: rideStart,
      rideEnd: rideEnd,
    );
    if (!match.accepted) continue;
    final thumb = await asset.thumbnailDataWithSize(
      const ThumbnailSize(256, 256),
      quality: 70,
    );
    out.add(
      GalleryPhotoCandidate(
        asset: asset,
        takenAt: taken,
        match: match,
        thumb: thumb,
      ),
    );
  }
  out.sort((a, b) => a.takenAt.compareTo(b.takenAt));
  return GalleryScanResult(
    candidates: out,
    limited: perm == PermissionState.limited,
  );
}

Future<List<AssetEntity>> _recentImages({DateTime? from, DateTime? to}) async {
  final filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    createTimeCond: from == null || to == null
        ? DateTimeCond.def()
        : DateTimeCond(min: from, max: to),
  );
  final paths = await PhotoManager.getAssetPathList(
    type: RequestType.image,
    filterOption: filter,
    onlyAll: true,
  );
  if (paths.isEmpty) return const [];
  final album = paths.first;
  final total = await album.assetCountAsync;
  if (total <= 0) return const [];
  return album.getAssetListRange(start: 0, end: total.clamp(0, 400));
}

Future<Uint8List?> loadGalleryBytes(AssetEntity asset) async {
  final data = await asset.originBytes;
  if (data != null && data.isNotEmpty) return data;
  return asset.thumbnailDataWithSize(
    const ThumbnailSize(1920, 1920),
    quality: 85,
  );
}
