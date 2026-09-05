import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_notification_service.dart';
import '../../core/services/location_service.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../providers/ride_providers.dart';
import '../ride_active/armed_session_flow.dart';
import '../watch/watch_providers.dart';
import 'rodada_live_session.dart';
import 'rodada_providers.dart';
import 'rodada_repository.dart';

/// Keeps pack GPS sharing, auto-arm, and family watch in sync with live rodadas.
///
/// Pack share cadence is owned by [RodadaLiveSession] (5 min / retry 1 min).
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
    final liveIds = await _liveRodadaIds(repo);
    if (!mounted) return;

    final wantShare = <String>{};
    for (final id in liveIds) {
      final m = await repo.myMembership(id);
      if (!mounted) return;
      if (m == null || m.rsvp == 'declined') continue;
      if (m.shareLive) wantShare.add(id);
      if (m.autoArmOnStart) unawaited(_maybeArm(id));
      if (m.autoShareFamily) unawaited(_maybeFamilyWatch(id));
    }

    _armedFor.removeWhere((id) => !liveIds.contains(id));
    _familyFor.removeWhere((id) => !liveIds.contains(id));

    for (final id in _sessions.keys.toList()) {
      if (!wantShare.contains(id)) {
        unawaited(_sessions.remove(id)?.dispose());
      }
    }
    for (final id in wantShare) {
      if (_sessions.containsKey(id)) continue;
      final session = RodadaLiveSession(rodadaId: id, repository: repo);
      _sessions[id] = session;
      unawaited(session.start());
    }
  }

  Future<Set<String>> _liveRodadaIds(RodadaRepository repo) async {
    try {
      final mine = await repo.listMyRodadas(limit: 30);
      return mine.where((r) => r.status == 'live').map((r) => r.id).toSet();
    } catch (e) {
      debugPrint('RodadaRouteShareBinder: $e');
      return {};
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
    if (_familyFor.contains(rodadaId)) return;
    final recorder = ref.read(rideRecorderProvider);
    final ride = recorder.activeRide;
    if (!recorder.isRecording || ride == null) return;
    if (!await _location.hasRecordingPermission()) return;
    _familyFor.add(rodadaId);
    try {
      final ctrl = ref.read(activeWatchControllerProvider.notifier);
      await ctrl.resumeFor(localRideId: ride.id);
      var session = ref.read(activeWatchControllerProvider);
      session ??= await ctrl.startForRide(localRideId: ride.id);
      if (session != null) await ctrl.ensureShareUrl();
    } catch (e) {
      _familyFor.remove(rodadaId);
      debugPrint('Rodada family watch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myRodadasProvider, (_, __) {
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
