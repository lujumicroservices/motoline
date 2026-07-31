import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/route_circuit.dart';
import '../supabase/supabase_bootstrap.dart';

/// Create / share / sync named routes (circuits).
class RouteService {
  RouteService({
    RideDatabase? database,
    SupabaseClient? client,
  })  : _db = database ?? RideDatabase.instance,
        _client = client;

  final RideDatabase _db;
  final SupabaseClient? _client;
  final _uuid = const Uuid();

  static const _loopPurgePref = 'loop_anchors_purged_v1';

  /// Last refresh error for Routes UI (auth / network).
  String? lastRefreshError;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  Future<List<RouteCircuit>> listLocal() => _db.listRoutes();

  Future<RouteCircuit> createRoute({
    required String name,
    String? description,
    bool isShared = true,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Route name required');
    }

    var id = _uuid.v4();
    final now = DateTime.now();
    String? ownerId;

    // Prefer cloud id so peers can join the same route_id.
    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          ownerId = userId;
          final row = await _supabase
              .from('routes')
              .insert({
                'owner_id': userId,
                'name': trimmed,
                'description': description?.trim().isEmpty == true
                    ? null
                    : description?.trim(),
                'is_shared': isShared,
              })
              .select()
              .single();
          id = row['id'] as String;
        }
      } catch (e) {
        debugPrint('CornerIQ route cloud create failed: $e');
      }
    }

    final route = RouteCircuit(
      id: id,
      name: trimmed,
      description: description,
      isShared: isShared,
      createdAt: now,
      ownerId: ownerId,
    );
    await _db.upsertRoute(route);
    return route;
  }

  Future<RouteCircuit> setShared(String routeId, bool shared) async {
    final existing = await _db.getRoute(routeId);
    if (existing == null) throw StateError('Route not found');
    final updated = existing.copyWith(isShared: shared);
    await _db.upsertRoute(updated);

    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        await _supabase.from('routes').update({
          'is_shared': shared,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', routeId);
      } catch (e) {
        debugPrint('CornerIQ route share sync: $e');
      }
    }
    return updated;
  }

  Future<RouteCircuit> rename(String routeId, String name) async {
    final existing = await _db.getRoute(routeId);
    if (existing == null) throw StateError('Route not found');
    final updated = existing.copyWith(name: name.trim());
    await _db.upsertRoute(updated);
    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        await _supabase.from('routes').update({
          'name': updated.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', routeId);
      } catch (e) {
        debugPrint('CornerIQ route rename sync: $e');
      }
    }
    return updated;
  }

  /// One-shot: clear A/B on every route this user owns (peers refresh clean).
  Future<void> purgeOwnedLoopAnchorsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_loopPurgePref) == true) return;

    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await _supabase.from('routes').update({
            'init_lat': null,
            'init_lng': null,
            'end_lat': null,
            'end_lng': null,
            'geofence_radius_m': 40,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('owner_id', userId);
        }
      } catch (e) {
        debugPrint('CornerIQ loop purge cloud: $e');
      }
    }

    await prefs.setBool(_loopPurgePref, true);
  }

  /// Pull cloud routes into local SQLite; return **my** routes for the UI.
  Future<List<RouteCircuit>> refreshFromCloud() async {
    lastRefreshError = null;
    if (!SupabaseBootstrap.isReady) {
      lastRefreshError = 'Cloud not configured';
      return listLocal();
    }

    try {
      final session = await SupabaseBootstrap.ensureSession();
      final me = session?.user.id ?? _supabase.auth.currentUser?.id;
      if (me == null) {
        lastRefreshError =
            SupabaseBootstrap.lastAuthError ?? 'Not signed in to cloud';
        return _db.listMyRoutes(null);
      }

      // Do not block listing on the one-shot purge.
      unawaited(purgeOwnedLoopAnchorsOnce());

      final rows = await _supabase
          .from('routes')
          .select()
          .order('created_at', ascending: false);

      final mineFromCloud = <RouteCircuit>[];
      for (final raw in (rows as List)) {
        try {
          final map = Map<String, dynamic>.from(raw as Map);
          final r = RouteCircuit.fromCloud(map);
          await _db.upsertRoute(r);
          if (!r.isLoopReady) {
            try {
              await _db.deleteLoopsForRoute(r.id);
            } catch (e) {
              debugPrint('CornerIQ deleteLoops skip: $e');
            }
          }
          if (r.ownerId == me) {
            mineFromCloud.add(r);
          }
        } catch (e) {
          debugPrint('CornerIQ route upsert skip: $e');
        }
      }

      // Prefer explicit owned query if the broad select somehow missed ours.
      if (mineFromCloud.isEmpty) {
        try {
          final ownedRows = await _supabase
              .from('routes')
              .select()
              .eq('owner_id', me)
              .order('created_at', ascending: false);
          for (final raw in (ownedRows as List)) {
            final r = RouteCircuit.fromCloud(
              Map<String, dynamic>.from(raw as Map),
            );
            await _db.upsertRoute(r);
            mineFromCloud.add(r);
          }
        } catch (e) {
          debugPrint('CornerIQ owned routes query: $e');
        }
      }

      return _db.listMyRoutes(me);
    } catch (e) {
      lastRefreshError = SupabaseBootstrap.lastAuthError ?? '$e';
      debugPrint('CornerIQ routes refresh: $e');
      return listLocal();
    }
  }

  Future<void> deleteRoute(String routeId) async {
    await _db.deleteRoute(routeId);

    if (!SupabaseBootstrap.isReady) return;
    try {
      await SupabaseBootstrap.ensureSession();
      await _supabase.from('routes').delete().eq('id', routeId);
    } catch (e) {
      debugPrint('CornerIQ route delete: $e');
    }
  }
}
