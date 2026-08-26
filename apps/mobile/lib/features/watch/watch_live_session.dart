import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'watch_repository.dart';

/// Coarse GPS pings for an active family-watch session.
class WatchLiveSession {
  WatchLiveSession({
    required this.sessionId,
    required WatchRepository repository,
    this.shareInterval = const Duration(minutes: 2),
    this.retryInterval = const Duration(minutes: 1),
  }) : _repo = repository;

  final String sessionId;
  final WatchRepository _repo;
  final Duration shareInterval;
  final Duration retryInterval;

  Timer? _timer;
  bool _disposed = false;
  bool _sending = false;

  Future<void> start() async {
    if (_disposed) return;
    // Do not call requestPermission — Play requires an in-app disclosure first.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      debugPrint('WatchLiveSession: location not granted');
      return;
    }
    unawaited(_tick());
    _armTimer(retry: false);
  }

  void _armTimer({required bool retry}) {
    _timer?.cancel();
    if (_disposed) return;
    _timer = Timer(retry ? retryInterval : shareInterval, () {
      unawaited(_tick());
    });
  }

  Future<void> _tick() async {
    if (_disposed || _sending) return;
    _sending = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (_disposed) return;
      await _repo.upsertPosition(
        sessionId: sessionId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed.isNaN ? null : pos.speed,
        heading: pos.heading.isNaN ? null : pos.heading,
      );
      _armTimer(retry: false);
    } catch (e) {
      debugPrint('WatchLiveSession tick: $e');
      _armTimer(retry: true);
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
