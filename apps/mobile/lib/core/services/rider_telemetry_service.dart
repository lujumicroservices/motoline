import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../supabase/supabase_bootstrap.dart';

/// Categories for cloud troubleshooting events (all riders).
abstract final class TelemetryCategory {
  static const ride = 'ride';
  static const gps = 'gps';
  static const arm = 'arm';
  static const sync = 'sync';
  static const camera = 'camera';
  static const ble = 'ble';
  static const loop = 'loop';
  static const app = 'app';
  static const error = 'error';
}

/// Queues device troubleshooting events locally and uploads to Supabase
/// (`camera_events` table, with [category]) so any rider session can be
/// inspected remotely.
class RiderTelemetryService {
  RiderTelemetryService({
    RideDatabase? database,
    SupabaseClient? client,
  })  : _db = database ?? RideDatabase.instance,
        _client = client;

  static final RiderTelemetryService instance = RiderTelemetryService();

  final RideDatabase _db;
  final SupabaseClient? _client;
  final _uuid = const Uuid();

  String? _activeRideLocalId;
  bool _flushing = false;
  DateTime? _lastHeartbeatAt;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  void bindRide(String? rideLocalId) {
    _activeRideLocalId = rideLocalId;
    _lastHeartbeatAt = null;
  }

  String? get activeRideLocalId => _activeRideLocalId;

  Future<void> log({
    required String category,
    required String eventType,
    Map<String, dynamic>? payload,
    double? latitude,
    double? longitude,
    String? rideLocalId,
  }) async {
    try {
      final id = _uuid.v4();
      final createdAt = DateTime.now();
      await _db.insertTelemetryEvent(
        id: id,
        category: category,
        rideLocalId: rideLocalId ?? _activeRideLocalId,
        eventType: eventType,
        payloadJson: jsonEncode(payload ?? const <String, dynamic>{}),
        latitude: latitude,
        longitude: longitude,
        createdAtMs: createdAt.millisecondsSinceEpoch,
      );
      // Best-effort upload; never block the ride path.
      // ignore: unawaited_futures
      flushPending();
    } catch (e) {
      debugPrint('RiderTelemetry log: $e');
    }
  }

  Future<void> error({
    required String where,
    required Object error,
    String category = TelemetryCategory.error,
    Map<String, dynamic>? payload,
    double? latitude,
    double? longitude,
    String? rideLocalId,
  }) {
    return log(
      category: category,
      eventType: 'error',
      rideLocalId: rideLocalId,
      latitude: latitude,
      longitude: longitude,
      payload: {
        'where': where,
        'error': '$error',
        ...?payload,
      },
    );
  }

  /// Sparse live sample while recording (at most ~1/min) for remote debug.
  Future<void> maybeRideHeartbeat({
    required double latitude,
    required double longitude,
    double? speedKmh,
    double? leanDegrees,
    double? accuracyMeters,
    int? pointCount,
    bool? isPaused,
  }) async {
    final now = DateTime.now();
    final last = _lastHeartbeatAt;
    if (last != null && now.difference(last) < const Duration(seconds: 60)) {
      return;
    }
    _lastHeartbeatAt = now;
    await log(
      category: TelemetryCategory.ride,
      eventType: 'heartbeat',
      latitude: latitude,
      longitude: longitude,
      payload: {
        'speed_kmh': speedKmh,
        'lean_degrees': leanDegrees,
        'accuracy_m': accuracyMeters,
        'point_count': pointCount,
        'paused': isPaused,
      },
    );
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

      final pending = await _db.listUnsyncedTelemetryEvents(limit: 300);
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
          'category': row['category'] ?? TelemetryCategory.camera,
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
      await _db.markTelemetryEventsSynced(ids);
      uploaded = ids.length;
    } catch (e) {
      debugPrint('RiderTelemetry flush: $e');
    } finally {
      _flushing = false;
    }
    return uploaded;
  }
}
