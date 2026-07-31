/// Cloud profile row (closed-beta friend list).
class RiderProfile {
  const RiderProfile({
    required this.id,
    this.displayName,
    this.createdAt,
  });

  final String id;
  final String? displayName;
  final DateTime? createdAt;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (id.length >= 8) return 'Rider ${id.substring(0, 8)}';
    return 'Rider';
  }

  factory RiderProfile.fromMap(Map<String, dynamic> map) => RiderProfile(
        id: map['id'] as String,
        displayName: map['display_name'] as String?,
        createdAt: map['created_at'] == null
            ? null
            : DateTime.tryParse(map['created_at'] as String),
      );
}

/// Shared cloud ride summary for peer compare.
class CloudRideSummary {
  const CloudRideSummary({
    required this.id,
    required this.userId,
    required this.localId,
    required this.startedAt,
    this.endedAt,
    this.distanceMeters = 0,
    this.pointCount = 0,
    this.maxSpeedMps,
    this.avgSpeedMps,
    this.maxLeanLeftDeg,
    this.maxLeanRightDeg,
    this.lineScore,
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
    this.displayName,
  });

  final String id;
  final String userId;
  final String localId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final int pointCount;
  final double? maxSpeedMps;
  final double? avgSpeedMps;
  final double? maxLeanLeftDeg;
  final double? maxLeanRightDeg;
  final int? lineScore;
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;
  final String? displayName;

  double get distanceKm => distanceMeters / 1000;
  double? get maxSpeedKmh =>
      maxSpeedMps == null ? null : maxSpeedMps! * 3.6;
  double? get avgSpeedKmh =>
      avgSpeedMps == null ? null : avgSpeedMps! * 3.6;

  Duration get duration {
    final end = endedAt ?? startedAt;
    return end.difference(startedAt);
  }

  String get riderLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (userId.length >= 8) return 'Rider ${userId.substring(0, 8)}';
    return 'Rider';
  }

  factory CloudRideSummary.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return CloudRideSummary(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      localId: map['local_id'] as String? ?? '',
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.tryParse(map['ended_at'] as String),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
      pointCount: (map['point_count'] as int?) ?? 0,
      maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble(),
      avgSpeedMps: (map['avg_speed_mps'] as num?)?.toDouble(),
      maxLeanLeftDeg: (map['max_lean_left_deg'] as num?)?.toDouble(),
      maxLeanRightDeg: (map['max_lean_right_deg'] as num?)?.toDouble(),
      lineScore: (map['line_score'] as num?)?.toInt(),
      minLat: (map['min_lat'] as num?)?.toDouble(),
      maxLat: (map['max_lat'] as num?)?.toDouble(),
      minLng: (map['min_lng'] as num?)?.toDouble(),
      maxLng: (map['max_lng'] as num?)?.toDouble(),
      displayName: displayName,
    );
  }
}

class CloudTrackPoint {
  const CloudTrackPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedMps,
    this.leanDegrees,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speedMps;
  final double? leanDegrees;

  double? get speedKmh =>
      speedMps == null ? null : speedMps! * 3.6;

  factory CloudTrackPoint.fromMap(Map<String, dynamic> map) => CloudTrackPoint(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String),
        speedMps: (map['speed_mps'] as num?)?.toDouble(),
        leanDegrees: (map['lean_degrees'] as num?)?.toDouble(),
      );
}
