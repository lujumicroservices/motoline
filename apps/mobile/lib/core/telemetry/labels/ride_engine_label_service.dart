import 'package:flutter/foundation.dart';

import '../../analytics/ride_analytics.dart';
import '../../db/ride_database.dart';
import '../../services/rider_telemetry_service.dart';
import '../../supabase/supabase_bootstrap.dart';
import 'ride_engine_label.dart';

/// Persists beta ride labels for lean/curve/brake engine training.
class RideEngineLabelService {
  RideEngineLabelService({
    RideDatabase? database,
    RiderTelemetryService? telemetry,
  })  : _db = database ?? RideDatabase.instance,
        _telemetry = telemetry ?? RiderTelemetryService.instance;

  static final RideEngineLabelService instance = RideEngineLabelService();

  final RideDatabase _db;
  final RiderTelemetryService _telemetry;

  Future<bool> hasLabel(String rideId) async {
    final row = await _db.getRideEngineLabel(rideId);
    return row != null;
  }

  Future<void> save(
    RideEngineLabel label, {
    RideAnalytics? analytics,
    String? bikeId,
  }) async {
    await _db.upsertRideEngineLabel(label.toDb());
    if (label.skipped) return;

    final payload = label.toTrainingPayload(
      neutralLeanDegrees: analytics?.neutralLeanDegrees,
      curveEventCount: analytics?.curveEvents.length,
      pointCount: analytics?.samples.length,
      distanceKm: analytics?.distanceKm,
      bikeId: bikeId,
    );

    await _telemetry.log(
      category: TelemetryCategory.engineLabel,
      eventType: 'ride_engine_label',
      rideLocalId: label.rideId,
      payload: payload,
    );

    try {
      await _upsertCloudRow(label, payload);
      await _db.markRideEngineLabelsSynced([label.rideId]);
      await _telemetry.flushPending();
    } catch (e) {
      debugPrint('RideEngineLabel sync: $e');
    }
  }

  Future<void> skip(String rideId) async {
    await save(
      RideEngineLabel(
        rideId: rideId,
        phoneMount: PhoneMountId.other,
        skipped: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _upsertCloudRow(
    RideEngineLabel label,
    Map<String, dynamic> payload,
  ) async {
    if (!SupabaseBootstrap.isReady) return;
    final userId = SupabaseBootstrap.client.auth.currentUser?.id;
    if (userId == null) return;
    await SupabaseBootstrap.client.from('ride_engine_labels').upsert(
      {
        'user_id': userId,
        'ride_local_id': label.rideId,
        'phone_mount': label.phoneMount,
        'lean_quality': label.leanQuality,
        'brake_feel': label.brakeFeel,
        'ride_context': label.rideContext,
        'notes': label.notes,
        'payload': payload,
        'labeled_at': label.createdAt.toUtc().toIso8601String(),
      },
      onConflict: 'user_id,ride_local_id',
    );
  }
}
