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

/// Controller for the rider's active watch while recording / on a rodada.
class ActiveWatchController extends Notifier<WatchSession?> {
  WatchLiveSession? _live;
  bool _resuming = false;

  @override
  WatchSession? build() {
    ref.onDispose(() {
      _live?.dispose();
      _live = null;
    });
    return null;
  }

  WatchRepository get _repo => ref.read(watchRepositoryProvider);

  Future<void> _attachLive(WatchSession session) async {
    if (_live != null && state?.id == session.id) {
      state = session;
      return;
    }
    _live?.dispose();
    _live = WatchLiveSession(sessionId: session.id, repository: _repo);
    await _live!.start();
    state = session;
  }

  /// Rehydrate an already-active cloud session (same ride/rodada key).
  Future<WatchSession?> resumeFor({required String localRideId}) async {
    if (!SupabaseBootstrap.isReady) return null;
    if (state != null &&
        state!.localRideId == localRideId &&
        state!.isActive) {
      final withUrl = await _repo.attachShareUrl(state!);
      state = withUrl;
      return withUrl;
    }
    if (_resuming) return state;
    _resuming = true;
    try {
      final existing = await _repo.activeSessionForRide(localRideId);
      if (existing == null) return state;
      await _attachLive(existing);
      return existing;
    } finally {
      _resuming = false;
    }
  }

  Future<WatchSession?> startForRide({
    required String localRideId,
    String? riderDisplayName,
  }) async {
    if (!SupabaseBootstrap.isReady) return null;
    if (state != null &&
        state!.localRideId == localRideId &&
        state!.isActive) {
      return _repo.attachShareUrl(state!);
    }
    final session = await _repo.startSession(
      localRideId: localRideId,
      riderDisplayName: riderDisplayName,
    );
    await _attachLive(session);
    return session;
  }

  /// Same live URL — safe to send to more people without breaking prior links.
  Future<String?> ensureShareUrl() async {
    final s = state;
    if (s == null) return null;
    final url = await _repo.ensureShareUrl(s.id);
    state = WatchSession(
      id: s.id,
      riderId: s.riderId,
      localRideId: s.localRideId,
      cloudRideId: s.cloudRideId,
      status: s.status,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      riderDisplayName: s.riderDisplayName,
      shareUrl: url,
    );
    return url;
  }

  /// New URL; previous magic links stop working.
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
