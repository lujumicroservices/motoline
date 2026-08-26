import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'rodada_repository.dart';

/// Coarse location share for the whole rodada route.
///
/// Cadence: success → wait **5 minutes**; failure → retry every **1 minute**
/// until a send succeeds, then return to the 5‑minute cadence.
/// Uses one-shot GPS (not a high-rate stream) to stay light on battery.
class RodadaLiveSession {
  RodadaLiveSession({
    required this.rodadaId,
    required RodadaRepository repository,
    this.presence = 'riding',
    this.shareInterval = const Duration(minutes: 5),
    this.retryInterval = const Duration(minutes: 1),
  }) : _repo = repository;

  final String rodadaId;
  final RodadaRepository _repo;
  final String presence;
  final Duration shareInterval;
  final Duration retryInterval;

  Timer? _timer;
  bool _disposed = false;
  bool _sending = false;
  int _failStreak = 0;

  Future<void> start() async {
    if (_disposed) return;
    // Do not call requestPermission here — Play requires an in-app disclosure
    // first (see LocationPermissionGate / RodadaLiveTab disclosure).
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      debugPrint('RodadaLiveSession: location not granted');
      return;
    }

    // First ping ASAP so the pack sees you, then follow cadence.
    unawaited(_tick());
    _armTimer(retry: false);
  }

  void _armTimer({required bool retry}) {
    _timer?.cancel();
    if (_disposed) return;
    final delay = retry ? retryInterval : shareInterval;
    _timer = Timer(delay, () {
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
      await _repo.upsertLivePosition(
        rodadaId: rodadaId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed.isNaN ? null : pos.speed,
        heading: pos.heading.isNaN ? null : pos.heading,
        presence: presence,
      );
      _failStreak = 0;
      _armTimer(retry: false);
    } catch (e) {
      _failStreak++;
      debugPrint(
        'RodadaLiveSession share fail (#$_failStreak), retry in '
        '${retryInterval.inMinutes}m: $e',
      );
      _armTimer(retry: true);
    } finally {
      _sending = false;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    try {
      await _repo.clearMyLivePosition(rodadaId);
    } catch (e) {
      debugPrint('RodadaLiveSession clear: $e');
    }
  }
}
