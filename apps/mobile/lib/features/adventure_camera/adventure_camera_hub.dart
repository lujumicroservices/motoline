import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'aggressive_riding_detector.dart';
import 'adventure_camera_prefs.dart';
import 'camera_controller.dart';
import 'camera_group_controller.dart';
import 'camera_zone_detector.dart';
import 'gopro/gopro_ble_camera.dart';
import 'models/adventure_camera_status.dart';
import 'models/camera_member.dart';
import 'models/camera_zone.dart';
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
  bool _zonesEnabled = false;
  bool _aggressiveEnabled = false;
  List<CameraMember> _group = const [];

  final CameraZoneDetector _zones = CameraZoneDetector();
  final AggressiveRidingDetector _aggressive = AggressiveRidingDetector();
  final _uuid = const Uuid();

  Stream<AdventureCameraStatus> get statusStream => _statusOut.stream;
  AdventureCameraStatus get status => _status;
  bool get isLabEnabled => _labEnabled;
  bool get syncWithRide => _syncWithRide;
  bool get syncPauseWithAutoPause => _syncPause;
  bool get zonesEnabled => _zonesEnabled;
  bool get aggressiveEnabled => _aggressiveEnabled;
  List<CameraZone> get zones => _zones.zones;
  List<CameraMember> get cameraGroup => List.unmodifiable(_group);
  String get backendId => _controller.backendId;

  bool get _anyTriggerEnabled =>
      _syncWithRide || _zonesEnabled || _aggressiveEnabled;

  bool get _hasStartZones =>
      _zones.zones.any((z) => z.action == CameraZoneAction.start);

  Future<void> hydrate() async {
    _labEnabled = await AdventureCameraPrefs.isLabEnabled();
    _syncWithRide = await AdventureCameraPrefs.syncWithRide();
    _syncPause = await AdventureCameraPrefs.syncPause();
    _zonesEnabled = await AdventureCameraPrefs.zonesEnabled();
    _aggressiveEnabled = await AdventureCameraPrefs.aggressiveEnabled();
    _zones.setZones(await AdventureCameraPrefs.zones());
    _group = await AdventureCameraPrefs.cameraGroup();
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

  Future<void> setZonesEnabled(bool value) async {
    _zonesEnabled = value;
    await AdventureCameraPrefs.setZonesEnabled(value);
  }

  Future<void> setAggressiveEnabled(bool value) async {
    _aggressiveEnabled = value;
    await AdventureCameraPrefs.setAggressiveEnabled(value);
  }

  Future<void> setZones(List<CameraZone> zones) async {
    _zones.setZones(zones);
    await AdventureCameraPrefs.setZones(zones);
  }

  Future<void> setCameraGroup(List<CameraMember> members) async {
    _group = List.of(members);
    await AdventureCameraPrefs.setCameraGroup(_group);
    if (_labEnabled) await _rebuildBackend();
  }

  Future<void> addCameraToGroup(GoProScanHit hit) async {
    if (_group.any((m) => m.remoteId == hit.remoteId)) return;
    final next = [
      ..._group,
      CameraMember(
        id: _uuid.v4(),
        remoteId: hit.remoteId,
        displayName: hit.displayName,
      ),
    ];
    await setCameraGroup(next);
  }

  Future<void> removeCameraFromGroup(String memberId) async {
    await setCameraGroup(_group.where((m) => m.id != memberId).toList());
  }

  Future<void> setCameraEnabled(String memberId, bool enabled) async {
    await setCameraGroup([
      for (final m in _group)
        if (m.id == memberId) m.copyWith(enabled: enabled) else m,
    ]);
  }

  /// Scan nearby GoPros (or fake hits in simulated backend).
  Future<List<GoProScanHit>> scanForCameras() async {
    final backend = await AdventureCameraPrefs.backend();
    if (backend == AdventureCameraPrefs.backendSimulated) {
      return [
        GoProScanHit(
          remoteId: 'sim-${_uuid.v4()}',
          displayName: 'Sim GoPro ${_group.length + 1}',
          rssi: -40,
        ),
      ];
    }
    return GoProBleCameraController.scanNearby();
  }

  Future<void> setBackend(String backend) async {
    await AdventureCameraPrefs.setBackend(backend);
    if (_labEnabled) await _rebuildBackend();
  }

  Future<void> connect() async {
    if (!_labEnabled) return;
    if (_controller is CameraGroupController) {
      await _controller.connect();
      return;
    }
    final preferred = _group.isNotEmpty
        ? _group.first.remoteId
        : await AdventureCameraPrefs.lastDeviceId();
    await _controller.connect(preferredDeviceId: preferred);
    await _persistDeviceIdIfReady();
  }

  Future<void> disconnect() async {
    await _controller.disconnect();
  }

  Future<void> startRecordingNow() => _ensureStartRecording();

  Future<void> stopRecordingNow() => _ensureStopRecording();

  /// Soft hook from ride lifecycle — connects and optionally starts shutter.
  Future<void> onRideStarted() async {
    if (!_labEnabled || !_anyTriggerEnabled) return;
    _zones.reset();
    _aggressive.reset();
    try {
      await _ensureConnected();
      if (!_controller.status.isReady) return;

      // Zone-only mode: stay ready until a start geofence (or aggressive).
      final waitForZone = _zonesEnabled && _hasStartZones && !_syncWithRide;
      if (waitForZone) {
        _emit(
          AdventureCameraStatus(
            phase: AdventureCameraPhase.ready,
            deviceName: _status.deviceName,
            message: 'Waiting for map start zone…',
            memberCount: _status.memberCount,
            readyCount: _status.readyCount,
            recordingCount: _status.recordingCount,
          ),
        );
        return;
      }

      if (_syncWithRide) {
        await _ensureStartRecording();
      }
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
    if (!_labEnabled) return;
    _zones.reset();
    _aggressive.reset();
    if (!_syncWithRide && !_zonesEnabled && !_aggressiveEnabled) return;
    try {
      await _ensureStopRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRideStopped: $e');
    }
  }

  Future<void> onRidePaused() async {
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    try {
      await _ensureStopRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRidePaused: $e');
    }
  }

  Future<void> onRideResumed() async {
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    try {
      await _ensureStartRecording();
    } catch (e) {
      debugPrint('AdventureCamera onRideResumed: $e');
    }
  }

  /// Feed live GPS/lean while a ride is recording (zones + aggressive).
  Future<void> onLiveSample({
    required double latitude,
    required double longitude,
    double? leanDegrees,
    double? speedKmh,
    DateTime? timestamp,
  }) async {
    if (!_labEnabled || !_anyTriggerEnabled) return;
    final now = timestamp ?? DateTime.now();

    if (_zonesEnabled && _zones.zones.isNotEmpty) {
      final action = _zones.feed(latitude: latitude, longitude: longitude);
      if (action == CameraZoneAction.start) {
        await _ensureConnected();
        await _ensureStartRecording();
      } else if (action == CameraZoneAction.stop) {
        await _ensureStopRecording();
      }
    }

    if (_aggressiveEnabled && !_controller.status.isRecording) {
      final fired = _aggressive.feed(
        timestamp: now,
        leanDegrees: leanDegrees,
        speedKmh: speedKmh,
      );
      if (fired) {
        await _ensureConnected();
        await _ensureStartRecording();
      }
    }
  }

  Future<void> dispose() async {
    await _statusSub?.cancel();
    await _controller.dispose();
    await _statusOut.close();
  }

  Future<void> _ensureConnected() async {
    if (_controller.status.isReady) return;
    await connect();
  }

  Future<void> _ensureStartRecording() async {
    if (!_labEnabled) return;
    if (!_controller.status.isReady &&
        _controller.status.phase != AdventureCameraPhase.recording) {
      await _ensureConnected();
    }
    if (!_controller.status.isReady &&
        _controller.status.phase != AdventureCameraPhase.recording) {
      return;
    }
    if (_controller.status.isRecording &&
        (_controller.status.recordingCount == null ||
            _controller.status.recordingCount ==
                _controller.status.memberCount)) {
      return;
    }
    await _controller.startRecording();
    _emit(_controller.status);
  }

  Future<void> _ensureStopRecording() async {
    if (_controller.status.phase == AdventureCameraPhase.recording ||
        _controller.status.isReady) {
      await _controller.stopRecording();
      _emit(_controller.status);
    }
  }

  Future<void> _persistDeviceIdIfReady() async {
    final c = _controller;
    if (c is GoProBleCameraController && c.status.isReady) {
      final id = c.remoteId;
      if (id != null && id.isNotEmpty) {
        await AdventureCameraPrefs.setLastDeviceId(id);
      }
    }
  }

  Future<void> _rebuildBackend() async {
    final backend = await AdventureCameraPrefs.backend();
    final AdventureCameraController next;
    if (backend == AdventureCameraPrefs.backendSimulated) {
      if (_group.isEmpty) {
        next = SimulatedCameraController();
      } else {
        next = CameraGroupController(
          members: _group,
          factory: (m) => SimulatedCameraController(displayName: m.displayName),
        );
      }
    } else if (_group.isEmpty) {
      // Legacy single-cam: scan first GoPro found.
      next = GoProBleCameraController();
    } else {
      next = CameraGroupController(
        members: _group,
        factory: (m) => GoProBleCameraController(label: m.displayName),
      );
    }
    await _swapController(next);
    if (backend == AdventureCameraPrefs.backendSimulated && _group.isEmpty) {
      await next.connect();
    } else if (_group.isEmpty) {
      _emit(
        const AdventureCameraStatus(
          phase: AdventureCameraPhase.idle,
          message: 'Lab on — add GoPros to the group or Connect to scan one',
        ),
      );
    }
    // Non-empty group: keep the controller's aggregated status from swap.
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
