/// One downsampled lean sample (~10 Hz) for apex localization.
class LeanSample {
  const LeanSample({
    this.id,
    required this.rideId,
    required this.timestampMs,
    required this.leanDegrees,
    this.gpsLeanDegrees,
    this.speedMps,
    this.confidence,
  });

  final int? id;
  final String rideId;
  final int timestampMs;
  final double leanDegrees;
  final double? gpsLeanDegrees;
  final double? speedMps;
  final double? confidence;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'ride_id': rideId,
        'timestamp_ms': timestampMs,
        'lean_degrees': leanDegrees,
        'gps_lean_degrees': gpsLeanDegrees,
        'speed_mps': speedMps,
        'confidence': confidence,
      };

  factory LeanSample.fromMap(Map<String, Object?> map) => LeanSample(
        id: map['id'] as int?,
        rideId: map['ride_id'] as String,
        timestampMs: (map['timestamp_ms'] as num).toInt(),
        leanDegrees: (map['lean_degrees'] as num).toDouble(),
        gpsLeanDegrees: (map['gps_lean_degrees'] as num?)?.toDouble(),
        speedMps: (map['speed_mps'] as num?)?.toDouble(),
        confidence: (map['confidence'] as num?)?.toDouble(),
      );
}
