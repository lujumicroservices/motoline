import '../../core/models/ride_stretch.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import 'reel_timeline.dart';

const reelMinPauseDuration = Duration(seconds: 45);
const reelPhotoClusterMeters = 80.0;

/// Rest stop inferred from a GPS time gap (auto-pause), not a database row.
class DetectedPause {
  const DetectedPause({
    required this.index,
    required this.latitude,
    required this.longitude,
    required this.startedAt,
    required this.endedAt,
  });

  /// 1-based index in chronological order among the kept pauses.
  final int index;
  final double latitude;
  final double longitude;
  final DateTime startedAt;
  final DateTime endedAt;

  Duration get duration => endedAt.difference(startedAt);
}

class ReelAlbumItem {
  const ReelAlbumItem({
    required this.id,
    this.localPath,
    this.storagePath,
    this.takenAt,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String? localPath;
  final String? storagePath;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
}

class ClusteredReelPhotos {
  const ClusteredReelPhotos({
    required this.pauses,
    required this.photosByPause,
    required this.onRoute,
  });

  final List<DetectedPause> pauses;
  final List<List<ReelAlbumItem>> photosByPause;
  final List<ReelAlbumItem> onRoute;
}

/// Gaps between recorded stretches that last at least [minDuration].
List<DetectedPause> detectRidePauses(
  List<TrackPoint> points, {
  Duration minDuration = reelMinPauseDuration,
  Duration gapThreshold = const Duration(seconds: 8),
}) {
  final stretches = rideStretchesFrom(points, maxGap: gapThreshold);
  if (stretches.length < 2) return const [];
  final out = <DetectedPause>[];
  for (var i = 0; i < stretches.length - 1; i++) {
    final prev = stretches[i];
    final next = stretches[i + 1];
    if (prev.points.isEmpty) continue;
    final startedAt = prev.endedAt;
    final endedAt = next.startedAt;
    final duration = endedAt.difference(startedAt);
    if (duration < minDuration) continue;
    final anchor = prev.points.last;
    out.add(
      DetectedPause(
        index: out.length + 1,
        latitude: anchor.latitude,
        longitude: anchor.longitude,
        startedAt: startedAt,
        endedAt: endedAt,
      ),
    );
  }
  return out;
}

/// Keeps the longest pauses up to [length.maxPauseChapters], then reorders
/// them along the route and reindexes from 1.
List<DetectedPause> capPausesForLength(
  List<DetectedPause> pauses,
  ReelLength length,
) {
  if (pauses.isEmpty) return const [];
  var kept = List<DetectedPause>.from(pauses);
  if (kept.length > length.maxPauseChapters) {
    kept.sort((a, b) => b.duration.compareTo(a.duration));
    kept = length.capPauses(kept);
  }
  kept.sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return [
    for (var i = 0; i < kept.length; i++)
      DetectedPause(
        index: i + 1,
        latitude: kept[i].latitude,
        longitude: kept[i].longitude,
        startedAt: kept[i].startedAt,
        endedAt: kept[i].endedAt,
      ),
  ];
}

int? pauseIndexForPhoto({
  required List<DetectedPause> pauses,
  DateTime? takenAt,
  double? latitude,
  double? longitude,
  double clusterMeters = reelPhotoClusterMeters,
}) {
  if (pauses.isEmpty) return null;
  if (takenAt != null) {
    for (var i = 0; i < pauses.length; i++) {
      final pause = pauses[i];
      if (!takenAt.isBefore(pause.startedAt) &&
          !takenAt.isAfter(pause.endedAt)) {
        return i;
      }
    }
  }
  if (latitude != null && longitude != null) {
    var best = -1;
    var bestD = clusterMeters;
    for (var i = 0; i < pauses.length; i++) {
      final d = haversineMeters(
        latitude,
        longitude,
        pauses[i].latitude,
        pauses[i].longitude,
      );
      if (d <= bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) return best;
  }
  return null;
}

ClusteredReelPhotos clusterAlbumToPauses({
  required List<DetectedPause> pauses,
  required List<ReelAlbumItem> photos,
  double clusterMeters = reelPhotoClusterMeters,
}) {
  final buckets = List.generate(pauses.length, (_) => <ReelAlbumItem>[]);
  final onRoute = <ReelAlbumItem>[];
  for (final photo in photos) {
    final index = pauseIndexForPhoto(
      pauses: pauses,
      takenAt: photo.takenAt,
      latitude: photo.latitude,
      longitude: photo.longitude,
      clusterMeters: clusterMeters,
    );
    if (index == null) {
      onRoute.add(photo);
    } else {
      buckets[index].add(photo);
    }
  }
  return ClusteredReelPhotos(
    pauses: pauses,
    photosByPause: buckets,
    onRoute: onRoute,
  );
}

/// Default video picks: up to 3 photos per stop, then on-route, up to [maxPhotos].
List<String> defaultSelectedPhotoIds({
  required ClusteredReelPhotos clustered,
  required int maxPhotos,
  int perPause = 3,
}) {
  final ids = <String>[];
  for (final group in clustered.photosByPause) {
    for (final photo in group.take(perPause)) {
      if (ids.length >= maxPhotos) return ids;
      ids.add(photo.id);
    }
  }
  for (final photo in clustered.onRoute) {
    if (ids.length >= maxPhotos) return ids;
    ids.add(photo.id);
  }
  return ids;
}

String formatPauseDuration(Duration duration) {
  if (duration.inHours >= 1) {
    final minutes = duration.inMinutes.remainder(60);
    if (minutes == 0) return '${duration.inHours} h';
    return '${duration.inHours} h $minutes min';
  }
  if (duration.inMinutes >= 1) return '${duration.inMinutes} min';
  return '${duration.inSeconds}s';
}
