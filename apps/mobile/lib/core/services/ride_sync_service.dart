import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/bbox_utils.dart';
import '../analytics/ride_analytics.dart';
import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/share_visibility.dart';
import '../models/track_point.dart';
import '../supabase/supabase_bootstrap.dart';
import 'rider_telemetry_service.dart';

/// How aggressively cloud GPS may overwrite local SQLite tracks.
enum TrackPullPolicy {
  /// Auto Garage / Lean Lab open: never wipe a local track that still has samples.
  fillGapsOnly,

  /// Settings sync: replace only when cloud is clearly richer (more lean + enough GPS).
  preferRicher,
}

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
  String? lastSyncError;
  final List<String> lastSyncFailures = [];

  /// Once we learn the remote has no `pressure_hpa`, stop sending it.
  static bool _omitPressureHpa = false;

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
    lastSyncError = null;
    lastSyncFailures.clear();
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
        payload: {
          'ok': ok,
          'fail': fail,
          'last_error': lastSyncError,
        },
      );
      await RiderTelemetryService.instance.flushPending();
    } catch (_) {}
    return (ok: ok, fail: fail);
  }

  /// Upsert ride summary + upload track points without destroying cloud backup
  /// until the new points are fully inserted.
  Future<String?> syncRide(String localRideId) async {
    try {
      if (!SupabaseBootstrap.isReady) {
        lastSyncError = 'Cloud not configured';
        return null;
      }
      await SupabaseBootstrap.ensureSession();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        lastSyncError =
            SupabaseBootstrap.lastAuthError ?? 'Not signed in to cloud';
        return null;
      }

      final ride = await _db.getRide(localRideId);
      if (ride == null || ride.status != RideStatus.completed) {
        return null;
      }

      final points = await _db.getPoints(localRideId);
      // Never upload an empty track over a ride that claimed it had GPS —
      // that destroys the only remaining cloud backup after a local wipe.
      if (points.isEmpty && ride.pointCount > 10) {
        lastSyncError =
            'Skipped upload for $localRideId: local GPS empty but ride had ${ride.pointCount} points';
        lastSyncFailures.add(lastSyncError!);
        debugPrint('CornerIQ sync skip empty wipe: $localRideId');
        return null;
      }

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
        'visibility': ride.visibility.dbValue,
        'is_shared': ride.visibility.legacyIsShared,
        'route_id': ride.routeId,
        'title': ride.title,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (bbox != null) ...bbox.toMap(),
      };

      final row = await _supabase
          .from('rides')
          .upsert(payload, onConflict: 'user_id,local_id')
          .select('id')
          .single();

      final cloudRideId = row['id'] as String;

      if (points.isNotEmpty) {
        await _uploadTrackPointsSafe(cloudRideId, points);
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
      lastSyncError = '$e';
      lastSyncFailures.add('$localRideId: $e');
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

  /// Insert new points first, then delete older rows. If insert fails, cloud
  /// backup stays intact (unlike delete-then-insert).
  Future<void> _uploadTrackPointsSafe(
    String cloudRideId,
    List<TrackPoint> points,
  ) async {
    int? maxIdBefore;
    try {
      final before = await _supabase
          .from('track_points')
          .select('id')
          .eq('ride_id', cloudRideId)
          .order('id', ascending: false)
          .limit(1);
      if (before.isNotEmpty) {
        maxIdBefore = (before.first['id'] as num?)?.toInt();
      }
    } catch (_) {}

    Future<void> insertAll({required bool withPressure}) async {
      const chunkSize = 200;
      for (var i = 0; i < points.length; i += chunkSize) {
        final end = math.min(i + chunkSize, points.length);
        final chunk = points
            .sublist(i, end)
            .map((p) => _pointRow(p, includePressure: withPressure))
            .toList();
        for (final row in chunk) {
          row['ride_id'] = cloudRideId;
        }
        await _supabase.from('track_points').insert(chunk);
      }
    }

    try {
      await insertAll(withPressure: !_omitPressureHpa);
    } catch (e) {
      final msg = '$e'.toLowerCase();
      if (!_omitPressureHpa && msg.contains('pressure_hpa')) {
        _omitPressureHpa = true;
        debugPrint('CornerIQ: remote missing pressure_hpa — retrying without it');
        await insertAll(withPressure: false);
      } else {
        rethrow;
      }
    }

    // New rows are inserted; remove only the previous generation.
    if (maxIdBefore != null) {
      await _supabase
          .from('track_points')
          .delete()
          .eq('ride_id', cloudRideId)
          .lte('id', maxIdBefore);
    }
  }

  /// Download this account's cloud rides (+ GPS points) into local Garage.
  Future<int> pullMyCloudRides({
    TrackPullPolicy policy = TrackPullPolicy.preferRicher,
  }) async {
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
      var keptLocal = 0;
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
            visibility: ShareVisibility.fromDb(
              map['visibility'],
              legacyIsShared:
                  map['is_shared'] == true || map['is_shared'] == 1,
            ),
            title: _str(map['title']),
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
                pressureHpa: (pm['pressure_hpa'] as num?)?.toDouble(),
              ),
            );
          }

          final localPoints = await _db.getPoints(localId);
          if (_shouldKeepLocalTrack(
            local: localPoints,
            cloud: points,
            policy: policy,
          )) {
            keptLocal++;
            debugPrint(
              'CornerIQ pull keep local track $localId '
              '(local ${localPoints.length}/${_leanCount(localPoints)} lean, '
              'cloud ${points.length}/${_leanCount(points)} lean, $policy)',
            );
          } else {
            await _db.replacePointsForRide(localId, points);
          }
          imported++;
        } catch (e) {
          debugPrint('CornerIQ pull ride skip: $e');
          lastPullError = '$e';
        }
      }

      lastPullInfo =
          'Pulled $imported cloud ride(s), kept local track on $keptLocal';
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

  Map<String, dynamic> _pointRow(
    TrackPoint p, {
    required bool includePressure,
  }) {
    final row = <String, dynamic>{
      'recorded_at': p.timestamp.toUtc().toIso8601String(),
      'latitude': p.latitude,
      'longitude': p.longitude,
      'altitude': p.altitude,
      'speed_mps': p.speedMps,
      'accuracy_meters': p.accuracyMeters,
      'heading': p.heading,
      'lean_degrees': p.leanDegrees,
    };
    if (includePressure && p.pressureHpa != null) {
      row['pressure_hpa'] = p.pressureHpa;
    }
    return row;
  }

  static int _leanCount(List<TrackPoint> pts) =>
      pts.where((p) => p.leanDegrees != null).length;

  /// Prefer denser / lean-richer local tracks so labeling keeps working.
  static bool _shouldKeepLocalTrack({
    required List<TrackPoint> local,
    required List<TrackPoint> cloud,
    required TrackPullPolicy policy,
  }) {
    if (local.isEmpty) return false;
    if (cloud.isEmpty) return true;

    final localLean = _leanCount(local);
    final cloudLean = _leanCount(cloud);

    switch (policy) {
      case TrackPullPolicy.fillGapsOnly:
        // Opening Garage / Lean Lab must never erase a ride that still has GPS.
        return true;
      case TrackPullPolicy.preferRicher:
        // Keep local whenever it still has lean and cloud has less.
        if (localLean > 0 && cloudLean < localLean) return true;
        // Keep local whenever it has denser GPS.
        if (cloud.length < local.length) return true;
        // Keep local if cloud has zero lean but local has any.
        if (localLean > 0 && cloudLean == 0) return true;
        return false;
    }
  }
}
