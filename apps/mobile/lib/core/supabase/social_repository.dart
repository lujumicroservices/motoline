import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/bbox_utils.dart';
import '../models/cloud_models.dart';
import '../models/route_circuit.dart';
import '../models/share_visibility.dart';
import '../supabase/supabase_bootstrap.dart';

/// Friends (all profiles) + same-area peer rides for closed beta.
class SocialRepository {
  SocialRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  Future<void> _ensure() async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    await SupabaseBootstrap.ensureSession();
  }

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<List<RiderProfile>> listFriends() async {
    await _ensure();
    final me = currentUserId;
    final rows = await _supabase
        .from('profiles')
        .select('id, display_name, created_at')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RiderProfile.fromMap)
        .where((p) => p.id != me)
        .toList();
  }

  Future<RiderProfile?> myProfile() async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return null;
    try {
      final row = await _supabase
          .from('profiles')
          .select('id, display_name, bike_id, created_at')
          .eq('id', me)
          .maybeSingle();
      if (row == null) return null;
      return RiderProfile.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      // Older schemas without bike_id.
      final row = await _supabase
          .from('profiles')
          .select('id, display_name, created_at')
          .eq('id', me)
          .maybeSingle();
      if (row == null) return null;
      return RiderProfile.fromMap(Map<String, dynamic>.from(row));
    }
  }

  Future<void> updateDisplayName(String name) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _supabase.from('profiles').update({
      'display_name': name.trim().isEmpty ? null : name.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', me);
  }

  Future<void> updateBikeId(String? bikeId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _supabase.from('profiles').update({
      'bike_id': bikeId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', me);
  }

  /// Peer shared rides whose bbox overlaps [bbox].
  Future<List<CloudRideSummary>> overlappingRides({
    required GeoBBox bbox,
    String? excludeCloudRideId,
  }) async {
    await _ensure();
    final rows = await _supabase.rpc(
      'rides_overlapping',
      params: {
        'p_min_lat': bbox.minLat,
        'p_max_lat': bbox.maxLat,
        'p_min_lng': bbox.minLng,
        'p_max_lng': bbox.maxLng,
        'p_exclude_ride_id': excludeCloudRideId,
        'p_pad_deg': GeoBBox.defaultPadDeg,
      },
    );

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];

    final userIds = list.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await _supabase
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final nameById = <String, String?>{
      for (final p in (profiles as List).cast<Map<String, dynamic>>())
        p['id'] as String: p['display_name'] as String?,
    };

    return list
        .map(
          (r) => CloudRideSummary.fromMap(
            r,
            displayName: nameById[r['user_id'] as String],
          ),
        )
        .toList();
  }

  Future<String?> cloudRideIdForLocal(String localId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return null;
    final row = await _supabase
        .from('rides')
        .select('id')
        .eq('user_id', me)
        .eq('local_id', localId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<List<CloudTrackPoint>> trackPoints(String cloudRideId) async {
    await _ensure();
    final rows = await _supabase
        .from('track_points')
        .select(
          'latitude, longitude, recorded_at, speed_mps, lean_degrees',
        )
        .eq('ride_id', cloudRideId)
        .order('recorded_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(CloudTrackPoint.fromMap)
        .toList();
  }

  Future<List<CloudRideSummary>> recentSharedRidesForUser(String userId) async {
    await _ensure();
    final rows = await _supabase
        .from('rides')
        .select()
        .eq('user_id', userId)
        .neq('visibility', 'private')
        .order('started_at', ascending: false)
        .limit(20);
    final profile = await _supabase
        .from('profiles')
        .select('display_name')
        .eq('id', userId)
        .maybeSingle();
    final name = profile?['display_name'] as String?;
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => CloudRideSummary.fromMap(r, displayName: name))
        .toList();
  }

  /// Peer shared rides tagged to the same named route.
  Future<List<CloudRideSummary>> peersOnRoute(String routeId) async {
    await _ensure();
    final me = currentUserId;
    final rows = await _supabase
        .from('rides')
        .select()
        .eq('route_id', routeId)
        .neq('visibility', 'private')
        .order('started_at', ascending: false)
        .limit(40);
    final list = (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['user_id'] != me)
        .toList();
    if (list.isEmpty) return const [];

    final userIds = list.map((r) => r['user_id'] as String).toSet().toList();
    final profiles = await _supabase
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', userIds);
    final nameById = <String, String?>{
      for (final p in (profiles as List).cast<Map<String, dynamic>>())
        p['id'] as String: p['display_name'] as String?,
    };

    return list
        .map(
          (r) => CloudRideSummary.fromMap(
            r,
            displayName: nameById[r['user_id'] as String],
          ),
        )
        .toList();
  }

  Future<List<RouteCircuitCloud>> listSharedRoutes() async {
    await _ensure();
    final me = currentUserId;
    final rows = await _supabase
        .from('routes')
        .select()
        .neq('visibility', 'private')
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['owner_id']?.toString() != me)
        .map(RouteCircuitCloud.fromMap)
        .toList();
  }
}

class RouteCircuitCloud {
  const RouteCircuitCloud({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.displayName,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? displayName;

  factory RouteCircuitCloud.fromMap(Map<String, dynamic> map) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return RouteCircuitCloud(
      id: str(map['id']) ?? '',
      ownerId: str(map['owner_id']) ?? '',
      name: str(map['name']) ?? '',
      description: str(map['description']),
    );
  }

  RouteCircuit toLocal() => RouteCircuit(
        id: id,
        name: name,
        description: description,
        visibility: ShareVisibility.public,
        createdAt: DateTime.now(),
        ownerId: ownerId,
      );
}
