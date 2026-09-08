import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/services/live_share_loop.dart';
import '../../core/services/location_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../providers/ride_providers.dart';
import '../ride_active/armed_session_flow.dart';
import '../watch/watch_providers.dart';
import '../watch/watch_repository.dart';
import 'rodada_live_session.dart';
import 'rodada_providers.dart';
import 'rodada_repository.dart';

/// Keeps pack GPS sharing, auto-arm, and family watch in sync with live rodadas.
///
/// Pack share cadence is owned by [RodadaLiveSession]. A catalog fetch failure
/// does **not** drop sessions — that used to kill the family magic link.
class RodadaRouteShareBinder extends ConsumerStatefulWidget {
  const RodadaRouteShareBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RodadaRouteShareBinder> createState() =>
      _RodadaRouteShareBinderState();
}

class _RodadaRouteShareBinderState
    extends ConsumerState<RodadaRouteShareBinder> {
  final Map<String, RodadaLiveSession> _sessions = {};
  final Set<String> _armedFor = {};
  final Set<String> _familyFor = {};
  final _location = LocationService();
  StreamSubscription<String>? _startedSub;
  Timer? _poll;
  bool _started = false;

  @override
  void dispose() {
    unawaited(_startedSub?.cancel());
    _poll?.cancel();
    for (final s in _sessions.values) {
      unawaited(s.dispose());
    }
    _sessions.clear();
    super.dispose();
  }

  Future<void> _reconcile() async {
    if (!SupabaseBootstrap.isReady) return;
    final repo = ref.read(rodadaRepositoryProvider);
    final catalog = await _shareCatalog(repo);
    if (!mounted) return;

    if (catalog == null) {
      for (final s in _sessions.values) {
        s.kick();
      }
      unawaited(ref.read(activeWatchControllerProvider.notifier).ensureLive());
      return;
    }

    final wantShare = nextLiveShareIds(
      fetchedWantShare: catalog.wantShare,
      currentSessionIds: _sessions.keys.toSet(),
    );

    _armedFor.removeWhere((id) => !catalog.liveIds.contains(id));
    _familyFor.removeWhere((id) => !catalog.liveIds.contains(id));

    for (final id in _sessions.keys.toList()) {
      if (!wantShare.contains(id)) {
        unawaited(_sessions.remove(id)?.dispose());
      }
    }
    for (final id in wantShare) {
      if (_sessions.containsKey(id)) {
        _sessions[id]?.kick();
        continue;
      }
      final session = RodadaLiveSession(rodadaId: id, repository: repo);
      _sessions[id] = session;
      unawaited(session.start());
    }

    for (final id in catalog.wantArm) {
      unawaited(_maybeArm(id));
    }
    for (final id in catalog.wantFamily) {
      unawaited(_maybeFamilyWatch(id));
    }
  }

  Future<_ShareCatalog?> _shareCatalog(RodadaRepository repo) async {
    try {
      final mine = await repo.listMyRodadas(limit: 30);
      final live = mine.where((r) => r.status == 'live').toList();
      final liveIds = live.map((r) => r.id).toSet();
      final wantShare = <String>{};
      final wantFamily = <String>{};
      final wantArm = <String>{};
      for (final r in live) {
        try {
          final m = await repo.myMembership(r.id);
          if (m == null || m.rsvp == 'declined') continue;
          if (m.shareLive) wantShare.add(r.id);
          if (m.autoArmOnStart) wantArm.add(r.id);
          if (m.autoShareFamily) wantFamily.add(r.id);
        } catch (e) {
          debugPrint('RodadaRouteShareBinder membership ${r.id}: $e');
          if (_sessions.containsKey(r.id)) wantShare.add(r.id);
          if (_familyFor.contains(r.id)) wantFamily.add(r.id);
        }
      }
      return _ShareCatalog(
        liveIds: liveIds,
        wantShare: wantShare,
        wantFamily: wantFamily,
        wantArm: wantArm,
      );
    } catch (e) {
      debugPrint('RodadaRouteShareBinder catalog: $e');
      return null;
    }
  }

  Future<void> _maybeArm(String rodadaId) async {
    if (_armedFor.contains(rodadaId)) return;
    final recorder = ref.read(rideRecorderProvider);
    if (recorder.isArmed || recorder.isRecording) {
      _armedFor.add(rodadaId);
      return;
    }
    if (!await _location.hasRecordingPermission()) return;
    _armedFor.add(rodadaId);
    try {
      await ref.read(armedStateProvider.notifier).arm();
      if (!mounted) return;
      ensureArmedSessionHub(context, ref);
    } catch (e) {
      _armedFor.remove(rodadaId);
      debugPrint('Rodada auto-arm: $e');
    }
  }

  Future<void> _maybeFamilyWatch(String rodadaId) async {
    final recorder = ref.read(rideRecorderProvider);
    final ride = recorder.activeRide;
    final preferred = ride?.id ?? WatchRepository.rodadaLocalRideId(rodadaId);
    if (!await _location.hasRecordingPermission()) return;
    try {
      final ctrl = ref.read(activeWatchControllerProvider.notifier);
      final session = await ctrl.ensureLive(preferredLocalRideId: preferred);
      if (session != null) {
        _familyFor.add(rodadaId);
        await ctrl.ensureShareUrl();
      }
    } catch (e) {
      debugPrint('Rodada family watch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myRodadasProvider, (_, _) {
      unawaited(_reconcile());
    });
    ref.listen(autoStartEventsProvider, (_, next) {
      next.whenData((_) => unawaited(_reconcile()));
    });
    if (!_started) {
      _started = true;
      _startedSub = PushNotificationService.rodadaStarted.listen((_) {
        ref.invalidate(myRodadasProvider);
        unawaited(_reconcile());
      });
      _poll = Timer.periodic(const Duration(seconds: 20), (_) {
        ref.invalidate(myRodadasProvider);
        unawaited(_reconcile());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_reconcile());
      });
    }
    return widget.child;
  }
}

class _ShareCatalog {
  const _ShareCatalog({
    required this.liveIds,
    required this.wantShare,
    required this.wantFamily,
    required this.wantArm,
  });

  final Set<String> liveIds;
  final Set<String> wantShare;
  final Set<String> wantFamily;
  final Set<String> wantArm;
}
