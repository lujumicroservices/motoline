/// One downsampled lean sample (~10 Hz) for apex localization and A/B replay.
class LeanSample {
  const LeanSample({
    this.id,
    required this.rideId,
    required this.timestampMs,
    required this.leanDegrees,
    this.gpsLeanDegrees,
    this.speedMps,
    this.confidence,
    this.vectorLean,
    this.pose,
    this.fusedRoll,
    this.fusedPitch,
  });

  final int? id;
  final String rideId;
  final int timestampMs;
  final double leanDegrees;
  final double? gpsLeanDegrees;
  final double? speedMps;
  final double? confidence;

  /// Clinometer magnitude from frozen g0 (unsigned).
  final double? vectorLean;

  /// `vertical_y` | `landscape_x` | `flat_z` | `unknown`
  final String? pose;

  final double? fusedRoll;
  final double? fusedPitch;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'ride_id': rideId,
        'timestamp_ms': timestampMs,
        'lean_degrees': leanDegrees,
        'gps_lean_degrees': gpsLeanDegrees,
        'speed_mps': speedMps,
        'confidence': confidence,
        'vector_lean': vectorLean,
        'pose': pose,
        'fused_roll': fusedRoll,
        'fused_pitch': fusedPitch,
      };

  factory LeanSample.fromMap(Map<String, Object?> map) => LeanSample(
        id: map['id'] as int?,
        rideId: map['ride_id'] as String,
        timestampMs: (map['timestamp_ms'] as num).toInt(),
        leanDegrees: (map['lean_degrees'] as num).toDouble(),
        gpsLeanDegrees: (map['gps_lean_degrees'] as num?)?.toDouble(),
        speedMps: (map['speed_mps'] as num?)?.toDouble(),
        confidence: (map['confidence'] as num?)?.toDouble(),
        vectorLean: (map['vector_lean'] as num?)?.toDouble(),
        pose: map['pose'] as String?,
        fusedRoll: (map['fused_roll'] as num?)?.toDouble(),
        fusedPitch: (map['fused_pitch'] as num?)?.toDouble(),
      );
}
