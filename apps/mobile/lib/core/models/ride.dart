import 'share_visibility.dart';

enum RideStatus { recording, completed, abandoned }

class Ride {
  const Ride({
    required this.id,
    required this.startedAt,
    required this.status,
    this.endedAt,
    this.distanceMeters = 0,
    this.pointCount = 0,
    this.maxSpeedMps,
    this.avgSpeedMps,
    this.maxLeanDegrees,
    this.routeId,
    this.visibility = ShareVisibility.friends,
    this.title,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final RideStatus status;
  final double distanceMeters;
  final int pointCount;
  final double? maxSpeedMps;
  final double? avgSpeedMps;

  /// Peak absolute lean (degrees) seen on this ride.
  final double? maxLeanDegrees;

  /// Local/cloud route id (same UUID when synced).
  final String? routeId;

  /// Cloud visibility: private / friends / public.
  final ShareVisibility visibility;

  /// Human title, e.g. `Cañadas - Moyahua` (from start/end geocode).
  final String? title;

  /// Legacy: true only when [visibility] is public.
  bool get isShared => visibility.legacyIsShared;

  /// Title if set, otherwise a short date label.
  String displayTitle({String Function(DateTime)? dateFormat}) {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (dateFormat != null) return dateFormat(startedAt);
    return startedAt.toLocal().toString().substring(0, 16);
  }

  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  double get distanceKm => distanceMeters / 1000;

  double? get maxSpeedKmh =>
      maxSpeedMps == null ? null : maxSpeedMps! * 3.6;

  double? get avgSpeedKmh =>
      avgSpeedMps == null ? null : avgSpeedMps! * 3.6;

  Map<String, Object?> toMap() => {
        'id': id,
        'started_at_ms': startedAt.millisecondsSinceEpoch,
        'ended_at_ms': endedAt?.millisecondsSinceEpoch,
        'status': status.name,
        'distance_meters': distanceMeters,
        'point_count': pointCount,
        'max_speed_mps': maxSpeedMps,
        'avg_speed_mps': avgSpeedMps,
        'max_lean_degrees': maxLeanDegrees,
        'route_id': routeId,
        'is_shared': visibility.legacyIsShared ? 1 : 0,
        'visibility': visibility.dbValue,
        'title': title,
      };

  factory Ride.fromMap(Map<String, Object?> map) => Ride(
        id: map['id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          map['started_at_ms'] as int,
        ),
        endedAt: map['ended_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['ended_at_ms'] as int),
        status: RideStatus.values.byName(map['status'] as String),
        distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
        pointCount: (map['point_count'] as int?) ?? 0,
        maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble(),
        avgSpeedMps: (map['avg_speed_mps'] as num?)?.toDouble(),
        maxLeanDegrees: (map['max_lean_degrees'] as num?)?.toDouble(),
        routeId: map['route_id'] as String?,
        visibility: ShareVisibility.fromDb(
          map['visibility'],
          legacyIsShared: (map['is_shared'] as int?) != 0,
        ),
        title: map['title'] as String?,
      );

  Ride copyWith({
    DateTime? endedAt,
    RideStatus? status,
    double? distanceMeters,
    int? pointCount,
    double? maxSpeedMps,
    double? avgSpeedMps,
    double? maxLeanDegrees,
    String? routeId,
    bool clearRouteId = false,
    bool? isShared,
    ShareVisibility? visibility,
    String? title,
    bool clearTitle = false,
  }) {
    var nextVis = visibility ?? this.visibility;
    if (visibility == null && isShared != null) {
      nextVis = isShared ? ShareVisibility.public : ShareVisibility.private;
    }
    return Ride(
      id: id,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      pointCount: pointCount ?? this.pointCount,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      maxLeanDegrees: maxLeanDegrees ?? this.maxLeanDegrees,
      routeId: clearRouteId ? null : (routeId ?? this.routeId),
      visibility: nextVis,
      title: clearTitle ? null : (title ?? this.title),
    );
  }
}
