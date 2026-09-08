import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/live_share_loop.dart';
import 'watch_repository.dart';

/// Coarse GPS pings for an active family-watch session.
class WatchLiveSession {
  WatchLiveSession({
    required this.sessionId,
    required WatchRepository repository,
    this.shareInterval = const Duration(minutes: 2),
  }) : _repo = repository;

  final String sessionId;
  final WatchRepository _repo;
  final Duration shareInterval;

  LiveShareLoop? _loop;
  DateTime? _lastTokenExtend;

  Future<void> start() async {
    _loop?.dispose();
    _loop = LiveShareLoop(
      shareInterval: shareInterval,
      publish: _publish,
      onTickError: (e) => debugPrint('WatchLiveSession tick: $e'),
    );
    await _loop!.start();
  }

  void kick() => _loop?.kick();

  Future<void> _publish(Position pos) async {
    await _repo.upsertPosition(
      sessionId: sessionId,
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedMps: pos.speed.isNaN ? null : pos.speed,
      heading: pos.heading.isNaN ? null : pos.heading,
    );
    final now = DateTime.now().toUtc();
    if (_lastTokenExtend == null ||
        now.difference(_lastTokenExtend!) > const Duration(minutes: 30)) {
      _lastTokenExtend = now;
      await _repo.extendShareTokens(sessionId);
    }
  }

  void dispose() {
    _loop?.dispose();
    _loop = null;
  }
}
