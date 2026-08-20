/// One raw 6-axis IMU sample (~50 Hz) for offline lean replay.
class RideImuSample {
  const RideImuSample({
    this.id,
    required this.rideId,
    required this.timestampMs,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
  });

  final int? id;
  final String rideId;
  final int timestampMs;
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'ride_id': rideId,
        'timestamp_ms': timestampMs,
        'ax': ax,
        'ay': ay,
        'az': az,
        'gx': gx,
        'gy': gy,
        'gz': gz,
      };

  factory RideImuSample.fromMap(Map<String, Object?> map) => RideImuSample(
        id: map['id'] as int?,
        rideId: map['ride_id'] as String,
        timestampMs: (map['timestamp_ms'] as num).toInt(),
        ax: (map['ax'] as num).toDouble(),
        ay: (map['ay'] as num).toDouble(),
        az: (map['az'] as num).toDouble(),
        gx: (map['gx'] as num).toDouble(),
        gy: (map['gy'] as num).toDouble(),
        gz: (map['gz'] as num).toDouble(),
      );
}
