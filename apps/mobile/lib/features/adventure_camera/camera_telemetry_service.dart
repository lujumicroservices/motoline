import 'package:flutter/foundation.dart';

import '../../core/services/rider_telemetry_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'adventure_camera_prefs.dart';
import 'models/camera_member.dart';
import 'models/camera_zone.dart';

/// Camera-lab facade over [RiderTelemetryService] (category = camera).
class CameraTelemetryService {
  CameraTelemetryService._();

  static final CameraTelemetryService instance = CameraTelemetryService._();

  final RiderTelemetryService _rider = RiderTelemetryService.instance;

  void bindRide(String? rideLocalId) => _rider.bindRide(rideLocalId);

  Future<void> log({
    required String eventType,
    Map<String, dynamic>? payload,
    double? latitude,
    double? longitude,
    String? rideLocalId,
  }) {
    return _rider.log(
      category: TelemetryCategory.camera,
      eventType: eventType,
      payload: payload,
      latitude: latitude,
      longitude: longitude,
      rideLocalId: rideLocalId,
    );
  }

  Future<void> pushConfigSnapshot({String? rideLocalId}) async {
    try {
      final prefs = <String, dynamic>{
        'lab_enabled': await AdventureCameraPrefs.isLabEnabled(),
        'sync_with_ride': await AdventureCameraPrefs.syncWithRide(),
        'sync_pause': await AdventureCameraPrefs.syncPause(),
        'zones_enabled': await AdventureCameraPrefs.zonesEnabled(),
        'aggressive_enabled': await AdventureCameraPrefs.aggressiveEnabled(),
        'backend': await AdventureCameraPrefs.backend(),
      };
      final zones = await AdventureCameraPrefs.zones();
      final group = await AdventureCameraPrefs.cameraGroup();
      final localRide = rideLocalId ?? _rider.activeRideLocalId;

      await log(
        eventType: 'config_snapshot',
        rideLocalId: localRide,
        payload: {
          'prefs': prefs,
          'zone_count': zones.length,
          'group_count': group.length,
          'zones': [for (final z in zones) z.toJson()],
          'camera_group': [for (final m in group) m.toJson()],
        },
      );

      if (!SupabaseBootstrap.isReady) return;
      await SupabaseBootstrap.ensureSession();
      final client = SupabaseBootstrap.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('camera_config_snapshots').insert({
        'user_id': userId,
        'ride_local_id': localRide,
        'prefs': prefs,
        'zones': [for (final z in zones) z.toJson()],
        'camera_group': [for (final m in group) m.toJson()],
      });
    } catch (e) {
      debugPrint('CameraTelemetry config snapshot: $e');
    }
  }

  Future<int> flushPending() => _rider.flushPending();

  Future<void> logPrefsChanged({
    required String key,
    required Object value,
  }) async {
    await log(
      eventType: 'prefs_changed',
      payload: {'key': key, 'value': value},
    );
    await pushConfigSnapshot();
  }

  static Map<String, dynamic> zonesSummary(List<CameraZone> zones) => {
        'count': zones.length,
        'starts': zones.where((z) => z.action == CameraZoneAction.start).length,
        'stops': zones.where((z) => z.action == CameraZoneAction.stop).length,
        'paired': zones
            .where(
              (z) =>
                  z.action == CameraZoneAction.start && z.partnerId != null,
            )
            .length,
      };

  static Map<String, dynamic> groupSummary(List<CameraMember> group) => {
        'count': group.length,
        'enabled': group.where((m) => m.enabled).length,
        'names': [for (final m in group) m.displayName],
      };
}
