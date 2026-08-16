import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'models/rodada_models.dart';
import 'rodada_repository.dart';

final rodadaRepositoryProvider = Provider<RodadaRepository>((ref) {
  return RodadaRepository();
});

/// Home / list: metadata only.
final myRodadasProvider =
    FutureProvider.autoDispose<List<RodadaSummary>>((ref) async {
  if (!SupabaseBootstrap.isReady) return const [];
  try {
    return await ref.watch(rodadaRepositoryProvider).listMyRodadas();
  } catch (_) {
    return const [];
  }
});

final rodadaOverviewProvider =
    FutureProvider.autoDispose.family<RodadaSummary?, String>((ref, id) async {
  if (!SupabaseBootstrap.isReady) return null;
  return ref.watch(rodadaRepositoryProvider).getRodada(id);
});

final rodadaMembersProvider = FutureProvider.autoDispose
    .family<List<RodadaMember>, String>((ref, id) async {
  if (!SupabaseBootstrap.isReady) return const [];
  return ref.watch(rodadaRepositoryProvider).listMembers(id);
});

final myRodadaMembershipProvider =
    FutureProvider.autoDispose.family<RodadaMember?, String>((ref, id) async {
  if (!SupabaseBootstrap.isReady) return null;
  return ref.watch(rodadaRepositoryProvider).myMembership(id);
});

/// Live positions — polls while watched; stops when tab disposes.
///
/// Merges into a last-known cache so a failed poll or brief GPS gap does not
/// wipe pins. Rows removed from the cloud (share-off) drop out of the cache.
final rodadaLivePositionsProvider = StreamProvider.autoDispose
    .family<List<RodadaLivePosition>, String>((ref, rodadaId) {
  if (!SupabaseBootstrap.isReady) {
    return Stream.value(const <RodadaLivePosition>[]);
  }
  final repo = ref.watch(rodadaRepositoryProvider);
  final controller = StreamController<List<RodadaLivePosition>>();
  final cache = <String, RodadaLivePosition>{};
  List<RodadaLivePosition>? lastEmitted;

  bool sameSnapshot(List<RodadaLivePosition> a, List<RodadaLivePosition> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void emit(List<RodadaLivePosition> next) {
    if (controller.isClosed) return;
    final prev = lastEmitted;
    if (prev != null && sameSnapshot(prev, next)) return;
    lastEmitted = next;
    controller.add(next);
  }

  Future<void> tick() async {
    if (controller.isClosed) return;
    try {
      final fresh = await repo.listLivePositions(rodadaId);
      final seen = <String>{};
      for (final p in fresh) {
        seen.add(p.userId);
        cache[p.userId] = p;
      }
      // Successful fetch: drop riders who turned sharing off (row deleted).
      cache.removeWhere((id, _) => !seen.contains(id));
      final merged = cache.values.toList(growable: false)
        ..sort((a, b) => a.label.compareTo(b.label));
      emit(merged);
    } catch (_) {
      // Keep last-known pins on network blips — never wipe to [].
      if (cache.isNotEmpty) {
        emit(cache.values.toList(growable: false));
      }
    }
  }

  unawaited(tick());
  final timer = Timer.periodic(const Duration(seconds: 5), (_) {
    unawaited(tick());
  });
  ref.onDispose(() {
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

/// Route sharing runs via [RodadaRouteShareBinder] (5 min / retry 1 min)
/// for the whole rodada — not tied to the Live tab lifecycle.

final rodadaStopsProvider =
    FutureProvider.autoDispose.family<List<RodadaStop>, String>((ref, id) {
  return ref.watch(rodadaRepositoryProvider).listStops(id);
});

final rodadaRidesProvider = FutureProvider.autoDispose
    .family<List<RodadaRideSummary>, String>((ref, id) async {
  if (!SupabaseBootstrap.isReady) return const [];
  return ref.watch(rodadaRepositoryProvider).listRodadaRides(id);
});

/// Heavy: downsampled track. Disposed when leaving ride map.
final rodadaRideTrackProvider = FutureProvider.autoDispose
    .family<List<({double lat, double lng})>, String>((ref, cloudRideId) {
  return ref
      .watch(rodadaRepositoryProvider)
      .trackPointsDownsampled(cloudRideId);
});

final rodadaPhotosProvider =
    FutureProvider.autoDispose.family<List<RodadaPhoto>, String>((ref, id) {
  return ref.watch(rodadaRepositoryProvider).listPhotos(id);
});

final rodadaPhotoUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, path) {
  return ref.watch(rodadaRepositoryProvider).signedPhotoUrl(path);
});

final rodadaMessagesProvider =
    FutureProvider.autoDispose.family<List<RodadaMessage>, String>((ref, id) {
  return ref.watch(rodadaRepositoryProvider).listMessages(id);
});
