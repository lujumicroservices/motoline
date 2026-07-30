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
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final RideStatus status;
  final double distanceMeters;
  final int pointCount;
  final double? maxSpeedMps;
  final double? avgSpeedMps;

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
      );

  Ride copyWith({
    DateTime? endedAt,
    RideStatus? status,
    double? distanceMeters,
    int? pointCount,
    double? maxSpeedMps,
    double? avgSpeedMps,
  }) =>
      Ride(
        id: id,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        status: status ?? this.status,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        pointCount: pointCount ?? this.pointCount,
        maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
        avgSpeedMps: avgSpeedMps ?? this.avgSpeedMps,
      );
}
