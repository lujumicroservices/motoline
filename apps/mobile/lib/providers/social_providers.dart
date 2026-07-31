import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/bbox_utils.dart';
import '../core/db/ride_database.dart';
import '../core/models/cloud_models.dart';
import '../core/models/route_circuit.dart';
import '../core/models/route_loop.dart';
import '../core/services/ride_sync_service.dart';
import '../core/services/route_loop_service.dart';
import '../core/services/route_service.dart';
import '../core/supabase/social_repository.dart';
import '../core/supabase/supabase_bootstrap.dart';

final rideSyncServiceProvider = Provider<RideSyncService>((ref) {
  return RideSyncService(database: RideDatabase.instance);
});

final routeServiceProvider = Provider<RouteService>((ref) {
  return RouteService(database: RideDatabase.instance);
});

final routeLoopServiceProvider = Provider<RouteLoopService>((ref) {
  return RouteLoopService(database: RideDatabase.instance);
});

final routeLoopsProvider =
    FutureProvider.autoDispose.family<List<RouteLoop>, String>((ref, routeId) {
  return ref.watch(routeLoopServiceProvider).listForRoute(routeId);
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

final routesListProvider =
    FutureProvider.autoDispose<List<RouteCircuit>>((ref) async {
  final service = ref.watch(routeServiceProvider);
  return service.refreshFromCloud();
});

final routesRefreshErrorProvider = Provider.autoDispose<String?>((ref) {
  ref.watch(routesListProvider);
  return ref.watch(routeServiceProvider).lastRefreshError;
});

final routesRefreshInfoProvider = Provider.autoDispose<String?>((ref) {
  ref.watch(routesListProvider);
  return ref.watch(routeServiceProvider).lastRefreshInfo;
});

final sharedPeerRoutesProvider =
    FutureProvider.autoDispose<List<RouteCircuitCloud>>((ref) async {
  if (!SupabaseBootstrap.isReady) return const [];
  try {
    return await ref.watch(socialRepositoryProvider).listSharedRoutes();
  } catch (_) {
    return const [];
  }
});

final friendsListProvider =
    FutureProvider.autoDispose<List<RiderProfile>>((ref) async {
  if (!SupabaseBootstrap.isReady) {
    throw StateError('Supabase not initialized');
  }
  try {
    return await ref.watch(socialRepositoryProvider).listFriends();
  } on AuthException catch (e) {
    throw StateError(_authHint(e.message));
  } catch (e) {
    final hint = SupabaseBootstrap.lastAuthError;
    if (hint != null && hint.isNotEmpty) {
      throw StateError(_authHint(hint));
    }
    rethrow;
  }
});

final myProfileProvider =
    FutureProvider.autoDispose<RiderProfile?>((ref) async {
  if (!SupabaseBootstrap.isReady) return null;
  try {
    return await ref.watch(socialRepositoryProvider).myProfile();
  } catch (_) {
    return null;
  }
});

String _authHint(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('anonymous') ||
      lower.contains('disabled') ||
      lower.contains('not enabled')) {
    return 'anonymous_disabled';
  }
  return message;
}

/// Peers for compare: same named route first, plus same-area bbox matches.
final overlappingPeersProvider = FutureProvider.autoDispose
    .family<List<CloudRideSummary>, String>((ref, localRideId) async {
  if (!SupabaseBootstrap.isReady) return const [];
  final db = RideDatabase.instance;
  final ride = await db.getRide(localRideId);
  if (ride == null) return const [];

  final social = ref.watch(socialRepositoryProvider);
  await ref.read(rideSyncServiceProvider).syncRide(localRideId);

  final byId = <String, CloudRideSummary>{};

  final routeId = ride.routeId;
  if (routeId != null && routeId.isNotEmpty) {
    try {
      for (final p in await social.peersOnRoute(routeId)) {
        byId[p.id] = p;
      }
    } catch (_) {}
  }

  final points = await db.getPoints(localRideId);
  final bbox = bboxFromPoints(points);
  if (bbox != null) {
    try {
      final excludeId = await social.cloudRideIdForLocal(localRideId);
      for (final p in await social.overlappingRides(
        bbox: bbox,
        excludeCloudRideId: excludeId,
      )) {
        byId.putIfAbsent(p.id, () => p);
      }
    } catch (_) {}
  }

  return byId.values.toList();
});

final friendRidesProvider = FutureProvider.autoDispose
    .family<List<CloudRideSummary>, String>((ref, userId) async {
  if (!SupabaseBootstrap.isReady) return const [];
  return ref.watch(socialRepositoryProvider).recentSharedRidesForUser(userId);
});
