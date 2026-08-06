/// Answers collected after a ride to train lean / curve / brake models.
class RideEngineLabel {
  const RideEngineLabel({
    required this.rideId,
    required this.phoneMount,
    this.leanQuality,
    this.brakeFeel,
    this.rideContext,
    this.notes,
    this.skipped = false,
    required this.createdAt,
    this.synced = false,
  });

  final String rideId;

  /// center_mount | left_pocket | right_pocket | other
  final String phoneMount;

  /// good | left_high | right_high | both_off | unsure
  final String? leanQuality;

  /// good | too_many | too_few | unsure
  final String? brakeFeel;

  /// street | mountain | track | commute | other
  final String? rideContext;

  final String? notes;
  final bool skipped;
  final DateTime createdAt;
  final bool synced;

  Map<String, Object?> toDb() => {
        'ride_id': rideId,
        'phone_mount': phoneMount,
        'lean_quality': leanQuality,
        'brake_feel': brakeFeel,
        'ride_context': rideContext,
        'notes': notes,
        'skipped': skipped ? 1 : 0,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  factory RideEngineLabel.fromDb(Map<String, Object?> row) {
    return RideEngineLabel(
      rideId: row['ride_id'] as String,
      phoneMount: row['phone_mount'] as String? ?? 'other',
      leanQuality: row['lean_quality'] as String?,
      brakeFeel: row['brake_feel'] as String?,
      rideContext: row['ride_context'] as String?,
      notes: row['notes'] as String?,
      skipped: (row['skipped'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at_ms'] as int? ?? 0,
      ),
      synced: (row['synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toTrainingPayload({
    double? neutralLeanDegrees,
    int? curveEventCount,
    int? pointCount,
    double? distanceKm,
    String? bikeId,
  }) {
    return {
      'schema': 'engine_label.v1',
      'ride_id': rideId,
      'phone_mount': phoneMount,
      'lean_quality': leanQuality,
      'brake_feel': brakeFeel,
      'ride_context': rideContext,
      'notes': notes,
      'skipped': skipped,
      'neutral_lean_deg': neutralLeanDegrees,
      'curve_event_count': curveEventCount,
      'point_count': pointCount,
      'distance_km': distanceKm,
      'bike_id': bikeId,
      'labeled_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Canonical choice ids (stable for ML / SQL).
abstract final class PhoneMountId {
  static const centerMount = 'center_mount';
  static const leftPocket = 'left_pocket';
  static const rightPocket = 'right_pocket';
  static const other = 'other';
}

abstract final class LeanQualityId {
  static const good = 'good';
  static const leftHigh = 'left_high';
  static const rightHigh = 'right_high';
  static const bothOff = 'both_off';
  static const unsure = 'unsure';
}

abstract final class BrakeFeelId {
  static const good = 'good';
  static const tooMany = 'too_many';
  static const tooFew = 'too_few';
  static const unsure = 'unsure';
}

abstract final class RideContextId {
  static const street = 'street';
  static const mountain = 'mountain';
  static const track = 'track';
  static const commute = 'commute';
  static const other = 'other';
}
