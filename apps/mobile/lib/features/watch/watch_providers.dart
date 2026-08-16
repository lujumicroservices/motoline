import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'watch_live_session.dart';
import 'watch_models.dart';
import 'watch_repository.dart';

final watchRepositoryProvider = Provider<WatchRepository>((ref) {
  return WatchRepository();
});

final trustedContactsProvider =
    FutureProvider.autoDispose<List<TrustedContact>>((ref) async {
  if (!SupabaseBootstrap.isReady) return const [];
  try {
    return await ref.watch(watchRepositoryProvider).listMyContacts();
  } catch (_) {
    return const [];
  }
});

final visibleWatchSessionsProvider =
    FutureProvider.autoDispose<List<WatchSession>>((ref) async {
  if (!SupabaseBootstrap.isReady) return const [];
  try {
    return await ref.watch(watchRepositoryProvider).listVisibleActiveSessions();
  } catch (_) {
    return const [];
  }
});

/// Controller for the rider's active watch while recording a ride.
class ActiveWatchController extends Notifier<WatchSession?> {
  WatchLiveSession? _live;

  @override
  WatchSession? build() {
    ref.onDispose(() {
      _live?.dispose();
      _live = null;
    });
    return null;
  }

  WatchRepository get _repo => ref.read(watchRepositoryProvider);

  Future<WatchSession?> startForRide({
    required String localRideId,
    String? riderDisplayName,
  }) async {
    if (!SupabaseBootstrap.isReady) return null;
    final session = await _repo.startSession(
      localRideId: localRideId,
      riderDisplayName: riderDisplayName,
    );
    _live?.dispose();
    _live = WatchLiveSession(sessionId: session.id, repository: _repo);
    await _live!.start();
    state = session;
    return session;
  }

  Future<String?> rotateLink() async {
    final s = state;
    if (s == null) return null;
    final next = await _repo.rotateShareLink(s.id);
    state = next;
    return next.shareUrl;
  }

  Future<void> postOk() async {
    final s = state;
    if (s == null) return;
    await _repo.postEvent(s.id, 'ok');
  }

  Future<void> postStopped() async {
    final s = state;
    if (s == null) return;
    await _repo.postEvent(s.id, 'stopped');
  }

  Future<void> postSos() async {
    final s = state;
    if (s == null) return;
    await _repo.postEvent(s.id, 'sos');
  }

  Future<void> end({bool cancelled = false}) async {
    final s = state;
    if (s == null) return;
    _live?.dispose();
    _live = null;
    await _repo.endSession(s.id, cancelled: cancelled);
    state = null;
  }
}

final activeWatchControllerProvider =
    NotifierProvider<ActiveWatchController, WatchSession?>(
  ActiveWatchController.new,
);
