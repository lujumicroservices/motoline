import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Retry delay after [failStreak] consecutive publish failures.
///
/// 15s, 30s, 60s… capped at [retryMax]. Success returns [shareInterval].
Duration liveShareRetryDelay({
  required int failStreak,
  required Duration shareInterval,
  Duration retryMin = const Duration(seconds: 15),
  Duration retryMax = const Duration(minutes: 1),
}) {
  if (failStreak <= 0) return shareInterval;
  final shift = min(failStreak - 1, 3);
  final seconds = retryMin.inSeconds * (1 << shift);
  final capped = min(seconds, retryMax.inSeconds);
  return Duration(seconds: capped);
}

/// When listing live rodadas fails, keep existing share sessions (do not wipe).
Set<String> nextLiveShareIds({
  required Set<String>? fetchedWantShare,
  required Set<String> currentSessionIds,
}) {
  if (fetchedWantShare == null) return currentSessionIds;
  return fetchedWantShare;
}

/// One-shot GPS with last-known fallback so tunnels / brief GPS loss still ping.
Future<Position?> readSharePosition({
  Duration timeout = const Duration(seconds: 22),
}) async {
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    ).timeout(timeout);
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

/// Periodic GPS publish with backoff, last-known fallback, and resume-on-foreground.
class LiveShareLoop {
  LiveShareLoop({
    required this.publish,
    this.shareInterval = const Duration(minutes: 2),
    this.retryMin = const Duration(seconds: 15),
    this.retryMax = const Duration(minutes: 1),
    this.onTickError,
  });

  final Future<void> Function(Position pos) publish;
  final Duration shareInterval;
  final Duration retryMin;
  final Duration retryMax;
  final void Function(Object error)? onTickError;

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;
  bool _sending = false;
  int _failStreak = 0;
  DateTime? _lastKickAt;

  Future<void> start() async {
    if (_disposed) return;
    _lifecycle ??= AppLifecycleListener(onResume: kick);
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      _armTimer(retry: true);
      return;
    }
    unawaited(_tick());
    _armTimer(retry: false);
  }

  /// Immediate retry (connectivity back, app resumed, binder poll).
  void kick() {
    if (_disposed) return;
    final now = DateTime.now();
    if (_lastKickAt != null &&
        now.difference(_lastKickAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastKickAt = now;
    unawaited(_tick());
  }

  void _armTimer({required bool retry}) {
    _timer?.cancel();
    if (_disposed) return;
    final delay = liveShareRetryDelay(
      failStreak: retry ? max(_failStreak, 1) : 0,
      shareInterval: shareInterval,
      retryMin: retryMin,
      retryMax: retryMax,
    );
    _timer = Timer(delay, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (_disposed || _sending) return;
    _sending = true;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _failStreak++;
        _armTimer(retry: true);
        return;
      }
      final pos = await readSharePosition();
      if (_disposed) return;
      if (pos == null) {
        _failStreak++;
        _armTimer(retry: true);
        return;
      }
      await publish(pos).timeout(const Duration(seconds: 20));
      if (_disposed) return;
      _failStreak = 0;
      _armTimer(retry: false);
    } catch (e) {
      _failStreak++;
      onTickError?.call(e);
      _armTimer(retry: true);
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
