import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/bbox_utils.dart';
import '../core/db/ride_database.dart';
import '../core/models/cloud_models.dart';
import '../core/services/ride_sync_service.dart';
import '../core/supabase/social_repository.dart';
import '../core/supabase/supabase_bootstrap.dart';

final rideSyncServiceProvider = Provider<RideSyncService>((ref) {
  return RideSyncService(database: RideDatabase.instance);
});

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

final friendsListProvider =
    FutureProvider.autoDispose<List<RiderProfile>>((ref) async {
  if (!SupabaseBootstrap.isReady) return const [];
  return ref.watch(socialRepositoryProvider).listFriends();
});

final myProfileProvider =
    FutureProvider.autoDispose<RiderProfile?>((ref) async {
  if (!SupabaseBootstrap.isReady) return null;
  return ref.watch(socialRepositoryProvider).myProfile();
});

final overlappingPeersProvider = FutureProvider.autoDispose
    .family<List<CloudRideSummary>, String>((ref, localRideId) async {
  if (!SupabaseBootstrap.isReady) return const [];
  final db = RideDatabase.instance;
  final points = await db.getPoints(localRideId);
  final bbox = bboxFromPoints(points);
  if (bbox == null) return const [];

  final social = ref.watch(socialRepositoryProvider);
  // Ensure our ride is uploaded so peers can match us too.
  await ref.read(rideSyncServiceProvider).syncRide(localRideId);
  final excludeId = await social.cloudRideIdForLocal(localRideId);
  return social.overlappingRides(
    bbox: bbox,
    excludeCloudRideId: excludeId,
  );
});

final friendRidesProvider = FutureProvider.autoDispose
    .family<List<CloudRideSummary>, String>((ref, userId) async {
  if (!SupabaseBootstrap.isReady) return const [];
  return ref.watch(socialRepositoryProvider).recentSharedRidesForUser(userId);
});
