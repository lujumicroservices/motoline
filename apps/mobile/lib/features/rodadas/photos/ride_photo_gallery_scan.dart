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

Future<List<GalleryPhotoCandidate>> scanRideGalleryPhotos({
  required DateTime rideStart,
  required DateTime rideEnd,
  required List<TrackPoint> points,
}) async {
  final perm = await PhotoManager.requestPermissionExtend();
  if (!perm.hasAccess) return const [];

  final from = rideStart.subtract(const Duration(minutes: 5));
  final to = rideEnd.add(const Duration(minutes: 15));
  final filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    createTimeCond: DateTimeCond(min: from, max: to),
  );
  final paths = await PhotoManager.getAssetPathList(
    type: RequestType.image,
    filterOption: filter,
    onlyAll: true,
  );
  if (paths.isEmpty) return const [];

  final album = paths.first;
  final total = await album.assetCountAsync;
  final assets = await album.getAssetListRange(
    start: 0,
    end: total.clamp(0, 400),
  );

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
  return out;
}

Future<Uint8List?> loadGalleryBytes(AssetEntity asset) async {
  final data = await asset.thumbnailDataWithSize(
    const ThumbnailSize(1920, 1920),
    quality: 85,
  );
  return data ?? await asset.originBytes;
}
