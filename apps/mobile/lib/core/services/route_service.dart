import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/route_circuit.dart';
import '../models/share_visibility.dart';
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

  /// Short diagnostic shown on Routes (e.g. synced counts / user id).
  String? lastRefreshInfo;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  Future<List<RouteCircuit>> listLocal() => _db.listRoutes();

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<RouteCircuit> createRoute({
    required String name,
    String? description,
    bool isShared = false,
    ShareVisibility visibility = ShareVisibility.friends,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Route name required');
    }

    final vis = isShared ? ShareVisibility.public : visibility;

    var id = _uuid.v4();
    final now = DateTime.now();
    String? ownerId;

    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        final userId = SupabaseBootstrap.permanentUserId;
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
                'visibility': vis.dbValue,
                'is_shared': vis.legacyIsShared,
              })
              .select()
              .single();
          id = _str(row['id']) ?? id;
        }
      } catch (e) {
        debugPrint('RiderLab route cloud create failed: $e');
      }
    }

    final route = RouteCircuit(
      id: id,
      name: trimmed,
      description: description,
      visibility: vis,
      createdAt: now,
      ownerId: ownerId,
    );
    await _db.upsertRoute(route);
    return route;
  }

  Future<RouteCircuit> setVisibility(
    String routeId,
    ShareVisibility visibility,
  ) async {
    final existing = await _db.getRoute(routeId);
    if (existing == null) throw StateError('Route not found');
    final updated = existing.copyWith(visibility: visibility);
    await _db.upsertRoute(updated);

    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        await _supabase.from('routes').update({
          'visibility': visibility.dbValue,
          'is_shared': visibility.legacyIsShared,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', routeId);
      } catch (e) {
        debugPrint('RiderLab route visibility sync: $e');
      }
    }
    return updated;
  }

  Future<RouteCircuit> setShared(String routeId, bool shared) {
    return setVisibility(
      routeId,
      shared ? ShareVisibility.public : ShareVisibility.private,
    );
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
        debugPrint('RiderLab route rename sync: $e');
      }
    }
    return updated;
  }

  Future<void> purgeOwnedLoopAnchorsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_loopPurgePref) == true) return;

    if (SupabaseBootstrap.isReady) {
      try {
        await SupabaseBootstrap.ensureSession();
        final userId = SupabaseBootstrap.permanentUserId;
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
        debugPrint('RiderLab loop purge cloud: $e');
      }
    }

    await prefs.setBool(_loopPurgePref, true);
  }

  RouteCircuit _parseCloudRoute(Map<String, dynamic> map) {
    final id = _str(map['id']);
    final name = _str(map['name']);
    if (id == null || name == null) {
      throw StateError('Route missing id/name');
    }
    final sharedRaw = map['is_shared'];
    final isShared = sharedRaw is bool
        ? sharedRaw
        : sharedRaw == true || sharedRaw == 1 || sharedRaw == 'true';

    return RouteCircuit(
      id: id,
      name: name,
      description: _str(map['description']),
      visibility: ShareVisibility.fromDb(
        map['visibility'],
        legacyIsShared: isShared,
      ),
      createdAt: DateTime.tryParse(_str(map['created_at']) ?? '') ??
          DateTime.now(),
      ownerId: _str(map['owner_id']),
      initLat: (map['init_lat'] as num?)?.toDouble(),
      initLng: (map['init_lng'] as num?)?.toDouble(),
      endLat: (map['end_lat'] as num?)?.toDouble(),
      endLng: (map['end_lng'] as num?)?.toDouble(),
      geofenceRadiusM: (map['geofence_radius_m'] as num?)?.toDouble(),
    );
  }

  /// Pull cloud routes; return **my** owned routes for the Routes UI.
  ///
  /// Uses the in-memory owned list as source of truth (does not depend on a
  /// SQLite re-read after upsert, which was empty for some devices).
  Future<List<RouteCircuit>> refreshFromCloud() async {
    lastRefreshError = null;
    lastRefreshInfo = null;
    if (!SupabaseBootstrap.isReady) {
      lastRefreshError = 'Cloud not configured';
      return listLocal();
    }

    try {
      final session = await SupabaseBootstrap.ensureSession();
      final me = _str(session?.user.id ?? SupabaseBootstrap.permanentUserId);
      if (me == null) {
        lastRefreshError =
            SupabaseBootstrap.lastAuthError ?? 'Not signed in to cloud';
        return listLocal();
      }

      // Skip one-shot A/B purge — it cleared loop anchors and confused riders.

      // 1) Explicit owned query first (what "My routes" needs).
      final ownedRows = await _supabase
          .from('routes')
          .select()
          .eq('owner_id', me)
          .order('created_at', ascending: false);

      final mine = <RouteCircuit>[];
      String? upsertError;
      for (final raw in (ownedRows as List)) {
        try {
          final r = _parseCloudRoute(Map<String, dynamic>.from(raw as Map));
          try {
            await _db.upsertRoute(r);
          } catch (e) {
            upsertError ??= '$e';
            debugPrint('RiderLab owned route upsert: $e');
          }
          mine.add(r);
        } catch (e) {
          upsertError ??= '$e';
          debugPrint('RiderLab owned route parse: $e');
        }
      }

      // 2) Also cache shared peer routes locally (for friend section / compare).
      try {
        final sharedRows = await _supabase
            .from('routes')
            .select()
            .neq('visibility', 'private')
            .order('created_at', ascending: false);
        for (final raw in (sharedRows as List)) {
          try {
            final r = _parseCloudRoute(Map<String, dynamic>.from(raw as Map));
            if (r.ownerId == me) continue;
            await _db.upsertRoute(r);
          } catch (e) {
            debugPrint('RiderLab shared route cache: $e');
          }
        }
      } catch (e) {
        debugPrint('RiderLab shared routes: $e');
      }

      final short = me.length > 8 ? me.substring(0, 8) : me;
      lastRefreshInfo =
          'Cloud ok · $short… · ${mine.length} own route(s)';
      if (upsertError != null && mine.isEmpty) {
        lastRefreshError = 'Local save failed: $upsertError';
      }

      if (mine.isNotEmpty) return mine;

      // Fallback: legacy local rows without owner.
      final local = await _db.listMyRoutes(me);
      if (local.isNotEmpty) return local;

      lastRefreshError ??=
          'No routes owned by this cloud account. Create one or ask to re-copy.';
      return const [];
    } catch (e) {
      lastRefreshError = SupabaseBootstrap.lastAuthError ?? '$e';
      debugPrint('RiderLab routes refresh: $e');
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
      debugPrint('RiderLab route delete: $e');
    }
  }
}
