import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'models/rodada_models.dart';
import 'rodada_live_session.dart';
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
final rodadaLivePositionsProvider = StreamProvider.autoDispose
    .family<List<RodadaLivePosition>, String>((ref, rodadaId) {
  if (!SupabaseBootstrap.isReady) {
    return Stream.value(const <RodadaLivePosition>[]);
  }
  final repo = ref.watch(rodadaRepositoryProvider);
  final controller = StreamController<List<RodadaLivePosition>>();

  Future<void> tick() async {
    if (controller.isClosed) return;
    try {
      controller.add(await repo.listLivePositions(rodadaId));
    } catch (_) {
      if (!controller.isClosed) {
        controller.add(const []);
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

/// Starts publishing only when this provider is watched (Live tab) AND
/// [shareLive] is true. Clears cloud position on dispose.
final rodadaLivePublisherProvider =
    Provider.autoDispose.family<void, String>((ref, rodadaId) {
  final membership = ref.watch(myRodadaMembershipProvider(rodadaId));
  final shareLive = membership.maybeWhen(
    data: (m) => m?.shareLive == true,
    orElse: () => false,
  );
  if (!shareLive || !SupabaseBootstrap.isReady) return;

  final session = RodadaLiveSession(
    rodadaId: rodadaId,
    repository: ref.watch(rodadaRepositoryProvider),
  );
  unawaited(session.start());
  ref.onDispose(() {
    unawaited(session.dispose());
  });
});

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
