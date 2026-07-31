import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/bbox_utils.dart';
import '../analytics/ride_analytics.dart';
import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../supabase/supabase_bootstrap.dart';

/// Uploads a completed local ride to Supabase (shared by default for closed beta).
class RideSyncService {
  RideSyncService({
    RideDatabase? database,
    SupabaseClient? client,
  })  : _db = database ?? RideDatabase.instance,
        _client = client;

  final RideDatabase _db;
  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
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
        'is_shared': true,
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
      return cloudRideId;
    } catch (e, st) {
      debugPrint('CornerIQ sync failed: $e\n$st');
      return null;
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
