import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/db/ride_database.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'adventure_camera_prefs.dart';
import 'models/camera_member.dart';
import 'models/camera_zone.dart';

/// Queues camera lab events locally and uploads them to Supabase for remote
/// troubleshooting (zones, aggressive triggers, shutter, BLE errors, prefs).
class CameraTelemetryService {
  CameraTelemetryService({
    RideDatabase? database,
    SupabaseClient? client,
  })  : _db = database ?? RideDatabase.instance,
        _client = client;

  static final CameraTelemetryService instance = CameraTelemetryService();

  final RideDatabase _db;
  final SupabaseClient? _client;
  final _uuid = const Uuid();

  String? _activeRideLocalId;
  bool _flushing = false;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  void bindRide(String? rideLocalId) {
    _activeRideLocalId = rideLocalId;
  }

  Future<void> log({
    required String eventType,
    Map<String, dynamic>? payload,
    double? latitude,
    double? longitude,
    String? rideLocalId,
  }) async {
    try {
      final id = _uuid.v4();
      final createdAt = DateTime.now();
      await _db.insertCameraEvent(
        id: id,
        rideLocalId: rideLocalId ?? _activeRideLocalId,
        eventType: eventType,
        payloadJson: jsonEncode(payload ?? const <String, dynamic>{}),
        latitude: latitude,
        longitude: longitude,
        createdAtMs: createdAt.millisecondsSinceEpoch,
      );
      // Best-effort upload; never block the camera path.
      // ignore: unawaited_futures
      flushPending();
    } catch (e) {
      debugPrint('CameraTelemetry log: $e');
    }
  }

  Future<void> pushConfigSnapshot({String? rideLocalId}) async {
    try {
      if (!SupabaseBootstrap.isReady) return;
      await SupabaseBootstrap.ensureSession();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

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

      await _supabase.from('camera_config_snapshots').insert({
        'user_id': userId,
        'ride_local_id': rideLocalId ?? _activeRideLocalId,
        'prefs': prefs,
        'zones': [for (final z in zones) z.toJson()],
        'camera_group': [for (final m in group) m.toJson()],
      });

      await log(
        eventType: 'config_snapshot',
        rideLocalId: rideLocalId ?? _activeRideLocalId,
        payload: {
          'prefs': prefs,
          'zone_count': zones.length,
          'group_count': group.length,
        },
      );
    } catch (e) {
      debugPrint('CameraTelemetry config snapshot: $e');
    }
  }

  Future<int> flushPending() async {
    if (_flushing) return 0;
    _flushing = true;
    var uploaded = 0;
    try {
      if (!SupabaseBootstrap.isReady) return 0;
      await SupabaseBootstrap.ensureSession();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final pending = await _db.listUnsyncedCameraEvents(limit: 200);
      if (pending.isEmpty) return 0;

      final rows = <Map<String, dynamic>>[];
      final ids = <String>[];
      for (final row in pending) {
        final id = row['id'] as String;
        ids.add(id);
        Map<String, dynamic> payload = {};
        try {
          final decoded = jsonDecode(row['payload_json'] as String? ?? '{}');
          if (decoded is Map<String, dynamic>) {
            payload = decoded;
          } else if (decoded is Map) {
            payload = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
        final createdMs = row['created_at_ms'] as int;
        rows.add({
          'user_id': userId,
          'local_id': id,
          'ride_local_id': row['ride_local_id'],
          'event_type': row['event_type'],
          'payload': payload,
          'latitude': row['latitude'],
          'longitude': row['longitude'],
          'created_at': DateTime.fromMillisecondsSinceEpoch(createdMs)
              .toUtc()
              .toIso8601String(),
        });
      }

      await _supabase.from('camera_events').upsert(
            rows,
            onConflict: 'user_id,local_id',
          );
      await _db.markCameraEventsSynced(ids);
      uploaded = ids.length;
    } catch (e) {
      debugPrint('CameraTelemetry flush: $e');
    } finally {
      _flushing = false;
    }
    return uploaded;
  }

  /// Convenience for settings toggles.
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
      };

  static Map<String, dynamic> groupSummary(List<CameraMember> group) => {
        'count': group.length,
        'enabled': group.where((m) => m.enabled).length,
        'names': [for (final m in group) m.displayName],
      };
}
