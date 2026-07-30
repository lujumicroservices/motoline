class TrackPoint {
  const TrackPoint({
    required this.id,
    required this.rideId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.speedMps,
    this.accuracyMeters,
    this.heading,
    this.leanDegrees,
  });

  final int? id;
  final String rideId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? speedMps;
  final double? accuracyMeters;
  final double? heading;

  /// Signed lean proxy from phone IMU (degrees). Positive = lean right.
  final double? leanDegrees;

  double? get speedKmh {
    final speed = speedMps;
    if (speed == null || speed < 0) return null;
    return speed * 3.6;
  }

  double? get absLeanDegrees => leanDegrees?.abs();

  bool get isLowAccuracy =>
      accuracyMeters != null && accuracyMeters! > 25;

  Map<String, Object?> toMap() => {
        'id': id,
        'ride_id': rideId,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'speed_mps': speedMps,
        'accuracy_meters': accuracyMeters,
        'heading': heading,
        'lean_degrees': leanDegrees,
        'timestamp_ms': timestamp.millisecondsSinceEpoch,
      };

  factory TrackPoint.fromMap(Map<String, Object?> map) => TrackPoint(
        id: map['id'] as int?,
        rideId: map['ride_id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        altitude: (map['altitude'] as num?)?.toDouble(),
        speedMps: (map['speed_mps'] as num?)?.toDouble(),
        accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
        heading: (map['heading'] as num?)?.toDouble(),
        leanDegrees: (map['lean_degrees'] as num?)?.toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          map['timestamp_ms'] as int,
        ),
      );

  TrackPoint copyWith({int? id, double? leanDegrees}) => TrackPoint(
        id: id ?? this.id,
        rideId: rideId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        altitude: altitude,
        speedMps: speedMps,
        accuracyMeters: accuracyMeters,
        heading: heading,
        leanDegrees: leanDegrees ?? this.leanDegrees,
      );
}
