import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'rodada_repository.dart';

/// Publishes coarse live GPS only while mounted. Call [dispose] when leaving
/// the Live tab so streams and cloud presence are released.
class RodadaLiveSession {
  RodadaLiveSession({
    required this.rodadaId,
    required RodadaRepository repository,
    this.presence = 'riding',
  }) : _repo = repository;

  final String rodadaId;
  final RodadaRepository _repo;
  final String presence;

  StreamSubscription<Position>? _sub;
  Timer? _throttle;
  Position? _pending;
  bool _disposed = false;
  DateTime? _lastSent;

  Future<void> start() async {
    if (_disposed) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final ok = await Geolocator.checkPermission();
    if (ok == LocationPermission.denied ||
        ok == LocationPermission.deniedForever) {
      debugPrint('RodadaLiveSession: location denied');
      return;
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    ).listen((pos) {
      _pending = pos;
      _scheduleFlush();
    }, onError: (e) {
      debugPrint('RodadaLiveSession stream: $e');
    });
  }

  void _scheduleFlush() {
    final last = _lastSent;
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(seconds: 4)) {
      _throttle ??= Timer(const Duration(seconds: 4), () {
        _throttle = null;
        unawaited(_flush());
      });
      return;
    }
    unawaited(_flush());
  }

  Future<void> _flush() async {
    if (_disposed) return;
    final pos = _pending;
    if (pos == null) return;
    _lastSent = DateTime.now();
    try {
      await _repo.upsertLivePosition(
        rodadaId: rodadaId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed.isNaN ? null : pos.speed,
        heading: pos.heading.isNaN ? null : pos.heading,
        presence: presence,
      );
    } catch (e) {
      debugPrint('RodadaLiveSession upsert: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _throttle?.cancel();
    _throttle = null;
    await _sub?.cancel();
    _sub = null;
    _pending = null;
    try {
      await _repo.clearMyLivePosition(rodadaId);
    } catch (e) {
      debugPrint('RodadaLiveSession clear: $e');
    }
  }
}
