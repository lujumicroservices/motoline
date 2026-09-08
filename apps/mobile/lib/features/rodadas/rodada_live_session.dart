import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/live_share_loop.dart';
import 'rodada_repository.dart';

/// Coarse location share for the whole rodada route.
///
/// Cadence: success → [shareInterval]; failure → 15s / 30s / 60s until a send
/// succeeds. Uses one-shot GPS (last-known fallback) to stay light on battery.
class RodadaLiveSession {
  RodadaLiveSession({
    required this.rodadaId,
    required RodadaRepository repository,
    this.presence = 'riding',
    this.shareInterval = const Duration(minutes: 5),
  }) : _repo = repository;

  final String rodadaId;
  final RodadaRepository _repo;
  final String presence;
  final Duration shareInterval;

  LiveShareLoop? _loop;
  bool _cleared = false;

  Future<void> start() async {
    _loop?.dispose();
    _loop = LiveShareLoop(
      shareInterval: shareInterval,
      publish: _publish,
      onTickError: (e) => debugPrint('RodadaLiveSession share fail: $e'),
    );
    await _loop!.start();
  }

  void kick() => _loop?.kick();

  Future<void> _publish(Position pos) async {
    await _repo.upsertLivePosition(
      rodadaId: rodadaId,
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedMps: pos.speed.isNaN ? null : pos.speed,
      heading: pos.heading.isNaN ? null : pos.heading,
      presence: presence,
    );
  }

  Future<void> dispose() async {
    _loop?.dispose();
    _loop = null;
    if (_cleared) return;
    _cleared = true;
    try {
      await _repo.clearMyLivePosition(rodadaId);
    } catch (e) {
      debugPrint('RodadaLiveSession clear: $e');
    }
  }
}
