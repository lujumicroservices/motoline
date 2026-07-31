import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adventure_camera_prefs.dart';
import 'camera_controller.dart';
import 'gopro/gopro_ble_camera.dart';
import 'models/adventure_camera_status.dart';
import 'noop_camera_controller.dart';
import 'simulated_camera_controller.dart';

/// Orchestrates the experimental camera lab.
///
/// Never throws into ride recording — all camera errors stay in [statusStream].
class AdventureCameraHub {
  AdventureCameraHub();

  AdventureCameraController _controller = NoopCameraController();
  StreamSubscription<AdventureCameraStatus>? _statusSub;
  final _statusOut = StreamController<AdventureCameraStatus>.broadcast();

  AdventureCameraStatus _status = AdventureCameraStatus.disabled;
  bool _labEnabled = false;
  bool _syncWithRide = true;
  bool _syncPause = false;

  Stream<AdventureCameraStatus> get statusStream => _statusOut.stream;
  AdventureCameraStatus get status => _status;
  bool get isLabEnabled => _labEnabled;
  bool get syncWithRide => _syncWithRide;
  bool get syncPauseWithAutoPause => _syncPause;
  String get backendId => _controller.backendId;

  Future<void> hydrate() async {
    _labEnabled = await AdventureCameraPrefs.isLabEnabled();
    _syncWithRide = await AdventureCameraPrefs.syncWithRide();
    _syncPause = await AdventureCameraPrefs.syncPause();
    if (!_labEnabled) {
      await _swapController(NoopCameraController());
      _emit(AdventureCameraStatus.disabled);
      return;
    }
    await _rebuildBackend();
  }

  Future<void> setLabEnabled(bool enabled) async {
    await AdventureCameraPrefs.setLabEnabled(enabled);
    _labEnabled = enabled;
    if (!enabled) {
      try {
        await _controller.stopRecording();
      } catch (_) {}
      await _swapController(NoopCameraController());
      _emit(AdventureCameraStatus.disabled);
      return;
    }
    await _rebuildBackend();
  }

  Future<void> setSyncWithRide(bool value) async {
    _syncWithRide = value;
    await AdventureCameraPrefs.setSyncWithRide(value);
  }

  Future<void> setSyncPause(bool value) async {
    _syncPause = value;
    await AdventureCameraPrefs.setSyncPause(value);
  }

  Future<void> setBackend(String backend) async {
    await AdventureCameraPrefs.setBackend(backend);
    if (_labEnabled) await _rebuildBackend();
  }

  Future<void> connect() async {
    if (!_labEnabled) return;
    final preferred = await AdventureCameraPrefs.lastDeviceId();
    await _controller.connect(preferredDeviceId: preferred);
  }

  Future<void> disconnect() async {
    await _controller.disconnect();
  }

  /// Soft hook from ride lifecycle — no-op unless lab + sync enabled.
  Future<void> onRideStarted() async {
    if (!_labEnabled || !_syncWithRide) return;
    try {
      if (!_controller.status.isReady &&
          _controller.status.phase != AdventureCameraPhase.recording) {
        await connect();
      }
      await _controller.startRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRideStarted: $e');
      _emit(
        AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          deviceName: _status.deviceName,
          message: '$e',
        ),
      );
    }
  }

  Future<void> onRideStopped() async {
    if (!_labEnabled || !_syncWithRide) return;
    try {
      await _controller.stopRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRideStopped: $e');
    }
  }

  Future<void> onRidePaused() async {
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    try {
      await _controller.stopRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRidePaused: $e');
    }
  }

  Future<void> onRideResumed() async {
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    try {
      await _controller.startRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRideResumed: $e');
    }
  }

  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _controller.dispose();
    await _statusOut.close();
  }

  Future<void> _rebuildBackend() async {
    final backend = await AdventureCameraPrefs.backend();
    final AdventureCameraController next = switch (backend) {
      AdventureCameraPrefs.backendSimulated => SimulatedCameraController(),
      _ => GoProBleCameraController(),
    };
    await _swapController(next);
    if (backend == AdventureCameraPrefs.backendSimulated) {
      await next.connect();
    } else {
      _emit(
        const AdventureCameraStatus(
          phase: AdventureCameraPhase.idle,
          message: 'Lab on — connect a GoPro',
        ),
      );
    }
  }

  Future<void> _swapController(AdventureCameraController next) async {
    await _statusSub?.cancel();
    try {
      await _controller.dispose();
    } catch (_) {}
    _controller = next;
    _statusSub = next.statusStream.listen(_emit);
    _emit(next.status);
  }

  void _emit(AdventureCameraStatus next) {
    _status = next;
    if (!_statusOut.isClosed) _statusOut.add(next);
  }
}
