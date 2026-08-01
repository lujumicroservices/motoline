import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/bbox_utils.dart';
import '../analytics/ride_analytics.dart';
import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../supabase/supabase_bootstrap.dart';
import 'rider_telemetry_service.dart';

/// Uploads completed local rides to Supabase, and pulls owned cloud rides
/// into local SQLite so Garage shows recovered / moved data.
class RideSyncService {
  RideSyncService({
    RideDatabase? database,
    SupabaseClient? client,
  })  : _db = database ?? RideDatabase.instance,
        _client = client;

  final RideDatabase _db;
  final SupabaseClient? _client;

  String? lastPullInfo;
  String? lastPullError;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Push every completed local ride (summary metrics + full GPS/lean track).
  Future<({int ok, int fail})> syncAllCompletedRides() async {
    var ok = 0;
    var fail = 0;
    final rides = await _db.listRides();
    for (final ride in rides) {
      if (ride.status != RideStatus.completed) continue;
      final cloudId = await syncRide(ride.id);
      if (cloudId != null) {
        ok++;
      } else {
        fail++;
      }
    }
    debugPrint('CornerIQ syncAll: $ok ok, $fail failed');
    try {
      await RiderTelemetryService.instance.log(
        category: TelemetryCategory.sync,
        eventType: 'sync_all_done',
        payload: {'ok': ok, 'fail': fail},
      );
      await RiderTelemetryService.instance.flushPending();
    } catch (_) {}
    return (ok: ok, fail: fail);
  }

  /// Upsert ride summary + replace track points. Soft-fails when offline / no auth.
  Future<String?> syncRide(String localRideId) async {
    try {
      if (!SupabaseBootstrap.isReady) return null;
      await SupabaseBootstrap.ensureSession();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final ride = await _db.getRide(localRideId);
      if (ride == null || ride.status != RideStatus.completed) return null;

      final points = await _db.getPoints(localRideId);
      final analytics = RideAnalytics(ride: ride, points: points);
      final bbox = bboxFromPoints(points);

      final payload = <String, dynamic>{
        'user_id': userId,
        'local_id': ride.id,
        'started_at': ride.startedAt.toUtc().toIso8601String(),
        'ended_at': ride.endedAt?.toUtc().toIso8601String(),
        'distance_meters': ride.distanceMeters,
        'point_count': points.length,
        'max_speed_mps': ride.maxSpeedMps,
        'avg_speed_mps': ride.avgSpeedMps,
        'max_lean_left_deg': analytics.maxLeanLeft,
        'max_lean_right_deg': analytics.maxLeanRight,
        'line_score': analytics.lineScore,
        'is_shared': ride.isShared,
        'route_id': ride.routeId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (bbox != null) ...bbox.toMap(),
      };

      final row = await _supabase
          .from('rides')
          .upsert(payload, onConflict: 'user_id,local_id')
          .select('id')
          .single();

      final cloudRideId = row['id'] as String;

      await _supabase.from('track_points').delete().eq('ride_id', cloudRideId);

      if (points.isNotEmpty) {
        const chunkSize = 200;
        for (var i = 0; i < points.length; i += chunkSize) {
          final end = math.min(i + chunkSize, points.length);
          final chunk = points.sublist(i, end).map(_pointRow).toList();
          for (final row in chunk) {
            row['ride_id'] = cloudRideId;
          }
          await _supabase.from('track_points').insert(chunk);
        }
      }

      debugPrint('CornerIQ synced ride $localRideId → $cloudRideId');
      try {
        await RiderTelemetryService.instance.log(
          category: TelemetryCategory.sync,
          eventType: 'ride_synced',
          rideLocalId: localRideId,
          payload: {
            'cloud_ride_id': cloudRideId,
            'point_count': points.length,
            'distance_m': ride.distanceMeters,
          },
        );
        await RiderTelemetryService.instance.flushPending();
      } catch (_) {}
      return cloudRideId;
    } catch (e, st) {
      debugPrint('CornerIQ sync failed: $e\n$st');
      try {
        await RiderTelemetryService.instance.error(
          where: 'sync.ride',
          error: e,
          category: TelemetryCategory.sync,
          rideLocalId: localRideId,
        );
      } catch (_) {}
      return null;
    }
  }

  /// Download this account's cloud rides (+ GPS points) into local Garage.
  Future<int> pullMyCloudRides() async {
    lastPullError = null;
    lastPullInfo = null;
    if (!SupabaseBootstrap.isReady) {
      lastPullError = 'Cloud not configured';
      return 0;
    }

    try {
      final session = await SupabaseBootstrap.ensureSession();
      final me = _str(session?.user.id ?? _supabase.auth.currentUser?.id);
      if (me == null) {
        lastPullError =
            SupabaseBootstrap.lastAuthError ?? 'Not signed in to cloud';
        return 0;
      }

      final rows = await _supabase
          .from('rides')
          .select()
          .eq('user_id', me)
          .order('started_at', ascending: false);

      var imported = 0;
      for (final raw in (rows as List)) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final cloudId = _str(map['id']);
          final localId = _str(map['local_id']) ?? cloudId;
          if (localId == null || cloudId == null) continue;

          final started = DateTime.tryParse(_str(map['started_at']) ?? '');
          if (started == null) continue;
          final ended = DateTime.tryParse(_str(map['ended_at']) ?? '');

          final leanL = (map['max_lean_left_deg'] as num?)?.toDouble();
          final leanR = (map['max_lean_right_deg'] as num?)?.toDouble();
          double? maxLean;
          if (leanL != null || leanR != null) {
            maxLean = math.max(leanL?.abs() ?? 0, leanR?.abs() ?? 0);
          }

          final ride = Ride(
            id: localId,
            startedAt: started.toLocal(),
            endedAt: ended?.toLocal(),
            status: RideStatus.completed,
            distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
            pointCount: (map['point_count'] as num?)?.toInt() ?? 0,
            maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble(),
            avgSpeedMps: (map['avg_speed_mps'] as num?)?.toDouble(),
            maxLeanDegrees: maxLean,
            routeId: _str(map['route_id']),
            isShared: map['is_shared'] == true || map['is_shared'] == 1,
          );
          await _db.upsertRide(ride);

          final pointRows = await _supabase
              .from('track_points')
              .select()
              .eq('ride_id', cloudId)
              .order('recorded_at');

          final points = <TrackPoint>[];
          for (final pr in (pointRows as List)) {
            final pm = Map<String, dynamic>.from(pr as Map);
            final ts = DateTime.tryParse(_str(pm['recorded_at']) ?? '');
            final lat = (pm['latitude'] as num?)?.toDouble();
            final lng = (pm['longitude'] as num?)?.toDouble();
            if (ts == null || lat == null || lng == null) continue;
            points.add(
              TrackPoint(
                id: null,
                rideId: localId,
                latitude: lat,
                longitude: lng,
                timestamp: ts.toLocal(),
                altitude: (pm['altitude'] as num?)?.toDouble(),
                speedMps: (pm['speed_mps'] as num?)?.toDouble(),
                accuracyMeters: (pm['accuracy_meters'] as num?)?.toDouble(),
                heading: (pm['heading'] as num?)?.toDouble(),
                leanDegrees: (pm['lean_degrees'] as num?)?.toDouble(),
              ),
            );
          }

          await _db.replacePointsForRide(localId, points);
          imported++;
        } catch (e) {
          debugPrint('CornerIQ pull ride skip: $e');
        }
      }

      lastPullInfo = 'Pulled $imported cloud ride(s)';
      return imported;
    } catch (e) {
      lastPullError = SupabaseBootstrap.lastAuthError ?? '$e';
      debugPrint('CornerIQ pull rides: $e');
      return 0;
    }
  }

  /// Delete a ride locally and, when online, its cloud copy (by `local_id`).
  Future<void> deleteRideEverywhere(String localRideId) async {
    await _db.deleteRide(localRideId);

    if (!SupabaseBootstrap.isReady) return;
    try {
      await SupabaseBootstrap.ensureSession();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await _supabase
          .from('rides')
          .select('id')
          .eq('local_id', localRideId)
          .eq('user_id', userId);
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final cloudId = _str(row['id']);
        if (cloudId == null) continue;
        await _supabase.from('track_points').delete().eq('ride_id', cloudId);
        await _supabase.from('rides').delete().eq('id', cloudId);
      }
    } catch (e) {
      debugPrint('CornerIQ ride cloud delete: $e');
    }
  }

  Map<String, dynamic> _pointRow(TrackPoint p) => {
        'recorded_at': p.timestamp.toUtc().toIso8601String(),
        'latitude': p.latitude,
        'longitude': p.longitude,
        'altitude': p.altitude,
        'speed_mps': p.speedMps,
        'accuracy_meters': p.accuracyMeters,
        'heading': p.heading,
        'lean_degrees': p.leanDegrees,
      };
}
