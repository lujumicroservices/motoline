import 'package:flutter/foundation.dart';
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

    // Prefer cloud id so peers can join the same route_id.
    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
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

  /// Pull own + shared peer routes into local cache.
  Future<List<RouteCircuit>> refreshFromCloud() async {
    if (!SupabaseBootstrap.isReady) return listLocal();
    try {
      await SupabaseBootstrap.ensureSession();
      final rows = await _supabase
          .from('routes')
          .select()
          .order('created_at', ascending: false);
      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(RouteCircuit.fromCloud)
          .toList();
      for (final r in list) {
        await _db.upsertRoute(r);
      }
      return listLocal();
    } catch (e) {
      debugPrint('CornerIQ routes refresh: $e');
      return listLocal();
    }
  }

  Future<void> deleteRoute(String routeId) async {
    await _db.deleteRoute(routeId);
    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        await _supabase.from('routes').delete().eq('id', routeId);
      } catch (e) {
        debugPrint('CornerIQ route delete: $e');
      }
    }
  }
}
