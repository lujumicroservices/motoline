import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'rodada_live_session.dart';
import 'rodada_providers.dart';
import 'rodada_repository.dart';

/// Keeps route location sharing alive for every rodada where the rider
/// opted into share_live — for the whole route, not only the Live tab.
///
/// Cadence is owned by [RodadaLiveSession] (5 min / retry 1 min).
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
  bool _started = false;

  @override
  void dispose() {
    for (final s in _sessions.values) {
      unawaited(s.dispose());
    }
    _sessions.clear();
    super.dispose();
  }

  Future<void> _reconcile() async {
    if (!SupabaseBootstrap.isReady) return;
    final repo = ref.read(rodadaRepositoryProvider);
    final want = await _wantedRodadaIds(repo);
    if (!mounted) return;

    final wantSet = want.toSet();
    for (final id in _sessions.keys.toList()) {
      if (!wantSet.contains(id)) {
        unawaited(_sessions.remove(id)?.dispose());
      }
    }
    for (final id in wantSet) {
      if (_sessions.containsKey(id)) continue;
      final session = RodadaLiveSession(
        rodadaId: id,
        repository: repo,
      );
      _sessions[id] = session;
      unawaited(session.start());
    }
  }

  Future<List<String>> _wantedRodadaIds(RodadaRepository repo) async {
    try {
      final mine = await repo.listMyRodadas(limit: 30);
      final active = mine.where(
        (r) => r.status == 'live' || r.status == 'open',
      );
      final ids = <String>[];
      for (final r in active) {
        final m = await repo.myMembership(r.id);
        if (m?.shareLive == true) ids.add(r.id);
      }
      return ids;
    } catch (e) {
      debugPrint('RodadaRouteShareBinder: $e');
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myRodadasProvider, (_, __) {
      unawaited(_reconcile());
    });
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_reconcile());
      });
    }
    return widget.child;
  }
}
