import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/route_circuit.dart';
import '../models/route_loop.dart';
import '../models/track_point.dart';
import '../supabase/supabase_bootstrap.dart';
import 'loop_detection.dart';
import 'loop_session_controller.dart';

/// CRUD + detection for [RouteLoop]s that belong to a route.
class RouteLoopService {
  RouteLoopService({RideDatabase? database})
      : _db = database ?? RideDatabase.instance;

  final RideDatabase _db;
  final _uuid = const Uuid();

  Future<List<RouteLoop>> listForRoute(String routeId) =>
      _db.listLoopsForRoute(routeId);

  Future<RouteLoop?> getPrimary(String routeId) =>
      _db.getPrimaryLoop(routeId);

  Future<RouteLoop> saveManual({
    required String routeId,
    required String name,
    required double initLat,
    required double initLng,
    required double endLat,
    required double endLng,
    double geofenceRadiusM = kLoopGeofenceRadiusMeters,
    bool makePrimary = true,
  }) async {
    final loop = RouteLoop(
      id: _uuid.v4(),
      routeId: routeId,
      name: name.trim().isEmpty ? 'Loop' : name.trim(),
      initLat: initLat,
      initLng: initLng,
      endLat: endLat,
      endLng: endLng,
      geofenceRadiusM: geofenceRadiusM,
      source: 'manual',
      createdAt: DateTime.now(),
      isPrimary: makePrimary,
    );
    await _persist(loop, makePrimary: makePrimary);
    return loop;
  }

  Future<RouteLoop> saveDetected({
    required String routeId,
    required DetectedLoopCandidate candidate,
    String? name,
    bool makePrimary = true,
  }) async {
    final loop = RouteLoop(
      id: _uuid.v4(),
      routeId: routeId,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'Detected ${(candidate.pathMeters / 1000).toStringAsFixed(1)} km',
      initLat: candidate.initLat,
      initLng: candidate.initLng,
      endLat: candidate.endLat,
      endLng: candidate.endLng,
      geofenceRadiusM: kLoopGeofenceRadiusMeters,
      source: 'detected',
      createdAt: DateTime.now(),
      sourceRideId: candidate.rideId,
      isPrimary: makePrimary,
    );
    await _persist(loop, makePrimary: makePrimary);
    return loop;
  }

  Future<void> setPrimary(String routeId, String loopId) async {
    final loop = await _db.getLoop(loopId);
    if (loop == null || loop.routeId != routeId) {
      throw StateError('Loop not found on route');
    }
    await _db.clearPrimaryLoops(routeId);
    final updated = loop.copyWith(isPrimary: true);
    await _db.upsertLoop(updated);
    await _mirrorPrimaryOntoRoute(updated);
  }

  Future<void> deleteLoop(String loopId) async {
    final loop = await _db.getLoop(loopId);
    if (loop == null) return;
    await _db.deleteLoop(loopId);
    if (loop.isPrimary) {
      final remaining = await _db.listLoopsForRoute(loop.routeId);
      if (remaining.isNotEmpty) {
        await setPrimary(loop.routeId, remaining.first.id);
      } else {
        await _clearRouteAnchors(loop.routeId);
        await _syncClearedAnchorsToCloud(loop.routeId);
      }
    }
  }

  /// Remove every loop on the route and clear A/B for all devices via cloud.
  Future<void> deleteAllLoops(String routeId) async {
    final loops = await _db.listLoopsForRoute(routeId);
    for (final loop in loops) {
      await _db.deleteLoop(loop.id);
    }
    await _clearRouteAnchors(routeId);
    await _syncClearedAnchorsToCloud(routeId);
  }

  Future<void> _syncClearedAnchorsToCloud(String routeId) async {
    if (!SupabaseBootstrap.isReady) return;
    try {
      await SupabaseBootstrap.ensureSession();
      await SupabaseBootstrap.client.from('routes').update({
        'init_lat': null,
        'init_lng': null,
        'end_lat': null,
        'end_lng': null,
        'geofence_radius_m': 40,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', routeId);
    } catch (e) {
      debugPrint('CornerIQ loop clear cloud: $e');
    }
  }

  /// Scan a single ride's GPS for closed-loop candidates.
  Future<List<DetectedLoopCandidate>> detectForRide(String rideId) async {
    final points = await _db.getPoints(rideId);
    final out = detectClosedLoops(rideId: rideId, points: points);
    out.sort((a, b) => b.pathMeters.compareTo(a.pathMeters));
    return out.take(8).toList();
  }

  /// Scan rides tagged to [routeId] and return closed-loop candidates.
  Future<List<DetectedLoopCandidate>> detectForRoute(String routeId) async {
    final rides = await _db.listRidesForRoute(routeId);
    final out = <DetectedLoopCandidate>[];
    for (final ride in rides) {
      if (ride.endedAt == null) continue;
      final points = await _db.getPoints(ride.id);
      out.addAll(detectClosedLoops(rideId: ride.id, points: points));
      if (out.length >= 12) break;
    }
    out.sort((a, b) => b.pathMeters.compareTo(a.pathMeters));
    return out.take(8).toList();
  }

  /// Track points from the newest ride on the route (for map mark UI).
  Future<List<TrackPoint>> trackPreviewForRoute(String routeId) async {
    final rides = await _db.listRidesForRoute(routeId);
    for (final ride in rides) {
      final points = await _db.getPoints(ride.id);
      if (points.length >= 2) return points;
    }
    return const [];
  }

  Future<void> _persist(RouteLoop loop, {required bool makePrimary}) async {
    if (makePrimary) {
      await _db.clearPrimaryLoops(loop.routeId);
    }
    await _db.upsertLoop(loop);
    if (makePrimary || loop.isPrimary) {
      await _mirrorPrimaryOntoRoute(loop.copyWith(isPrimary: true));
    }
  }

  /// Keep legacy route init/end columns in sync for session / badges + peers.
  Future<void> _mirrorPrimaryOntoRoute(RouteLoop loop) async {
    final route = await _db.getRoute(loop.routeId);
    if (route == null) return;
    final updated = route.copyWith(
      initLat: loop.initLat,
      initLng: loop.initLng,
      endLat: loop.endLat,
      endLng: loop.endLng,
      geofenceRadiusM: loop.geofenceRadiusM,
    );
    await _db.upsertRoute(updated);
    await _syncAnchorsToCloud(updated);
    debugPrint('RouteLoop mirrored onto route ${loop.routeId}');
  }

  Future<void> _syncAnchorsToCloud(RouteCircuit route) async {
    if (!SupabaseBootstrap.isReady) return;
    try {
      await SupabaseBootstrap.ensureSession();
      await SupabaseBootstrap.client.from('routes').update({
        'init_lat': route.initLat,
        'init_lng': route.initLng,
        'end_lat': route.endLat,
        'end_lng': route.endLng,
        'geofence_radius_m': route.geofenceRadiusM ?? 40,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', route.id);
    } catch (e) {
      debugPrint('CornerIQ loop anchors cloud: $e');
    }
  }

  Future<void> _clearRouteAnchors(String routeId) async {
    final route = await _db.getRoute(routeId);
    if (route == null) return;
    // copyWith can't clear nulls — write via map.
    final cleared = RouteCircuit(
      id: route.id,
      name: route.name,
      description: route.description,
      isShared: route.isShared,
      createdAt: route.createdAt,
    );
    await _db.upsertRoute(cleared);
  }
}
