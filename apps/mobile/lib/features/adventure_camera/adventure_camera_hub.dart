import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'aggressive_riding_detector.dart';
import 'adventure_camera_prefs.dart';
import 'camera_controller.dart';
import 'camera_group_controller.dart';
import 'camera_telemetry_service.dart';
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
  final CameraTelemetryService _telemetry = CameraTelemetryService.instance;

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
    unawaited(_telemetry.logPrefsChanged(key: 'lab_enabled', value: enabled));
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
    unawaited(
      _telemetry.logPrefsChanged(key: 'sync_with_ride', value: value),
    );
  }

  Future<void> setSyncPause(bool value) async {
    _syncPause = value;
    await AdventureCameraPrefs.setSyncPause(value);
    unawaited(_telemetry.logPrefsChanged(key: 'sync_pause', value: value));
  }

  Future<void> setZonesEnabled(bool value) async {
    _zonesEnabled = value;
    await AdventureCameraPrefs.setZonesEnabled(value);
    unawaited(
      _telemetry.logPrefsChanged(key: 'zones_enabled', value: value),
    );
  }

  Future<void> setAggressiveEnabled(bool value) async {
    _aggressiveEnabled = value;
    await AdventureCameraPrefs.setAggressiveEnabled(value);
    unawaited(
      _telemetry.logPrefsChanged(key: 'aggressive_enabled', value: value),
    );
  }

  Future<void> setZones(List<CameraZone> zones) async {
    _zones.setZones(zones);
    await AdventureCameraPrefs.setZones(zones);
    unawaited(
      _telemetry.log(
        eventType: 'zones_updated',
        payload: CameraTelemetryService.zonesSummary(zones),
      ),
    );
    unawaited(_telemetry.pushConfigSnapshot());
  }

  /// One-tap tester presets (Settings → Lab).
  Future<void> applyZoneOnlyPreset() async {
    await setLabEnabled(true);
    await setSyncWithRide(false);
    await setSyncPause(false);
    await setZonesEnabled(true);
    await setAggressiveEnabled(false);
    unawaited(_telemetry.log(eventType: 'preset_zone_only'));
  }

  Future<void> applyAggressiveOnlyPreset() async {
    await setLabEnabled(true);
    await setSyncWithRide(false);
    await setSyncPause(false);
    await setZonesEnabled(false);
    await setAggressiveEnabled(true);
    unawaited(_telemetry.log(eventType: 'preset_aggressive_only'));
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
  Future<void> onRideStarted({String? rideLocalId}) async {
    if (rideLocalId != null) _telemetry.bindRide(rideLocalId);
    if (!_labEnabled || !_anyTriggerEnabled) return;
    _zones.reset();
    _aggressive.reset();
    unawaited(
      _telemetry.log(
        eventType: 'ride_started',
        payload: {
          'sync_with_ride': _syncWithRide,
          'zones_enabled': _zonesEnabled,
          'aggressive_enabled': _aggressiveEnabled,
          'has_start_zones': _hasStartZones,
          'zone_count': _zones.zones.length,
          'group': CameraTelemetryService.groupSummary(_group),
        },
      ),
    );
    unawaited(_telemetry.pushConfigSnapshot(rideLocalId: rideLocalId));
    try {
      // Start geofences always gate shutter start (even if sync-with-ride is on).
      // Also skip BLE connect here to save phone + camera battery until needed.
      final zonesGateStart = _zonesEnabled && _hasStartZones;
      if (zonesGateStart) {
        unawaited(_telemetry.log(eventType: 'waiting_start_zone'));
        _emit(
          AdventureCameraStatus(
            phase: AdventureCameraPhase.idle,
            deviceName: _status.deviceName,
            message:
                'Waiting for map start zone — camera stays off to save battery',
            memberCount: _status.memberCount,
            readyCount: 0,
            recordingCount: 0,
          ),
        );
        return;
      }

      if (_syncWithRide) {
        await _ensureConnected();
        if (!_controller.status.isReady) return;
        await _ensureStartRecording();
        return;
      }

      // Aggressive-only: stay disconnected until motion triggers.
      if (_aggressiveEnabled) {
        unawaited(_telemetry.log(eventType: 'waiting_aggressive'));
        _emit(
          AdventureCameraStatus(
            phase: AdventureCameraPhase.idle,
            deviceName: _status.deviceName,
            message: 'Waiting for aggressive riding — camera off',
            memberCount: _status.memberCount,
          ),
        );
      }
    } catch (e) {
      debugPrint('AdventureCamera onRideStarted: $e');
      unawaited(
        _telemetry.log(eventType: 'error', payload: {'where': 'ride_started', 'error': '$e'}),
      );
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
    if (!_syncWithRide && !_zonesEnabled && !_aggressiveEnabled) {
      _telemetry.bindRide(null);
      return;
    }
    try {
      await _ensureStopRecording();
      // Drop BLE when the ride ends — big battery win vs keep-alive forever.
      await disconnect();
      _emit(_controller.status);
      unawaited(_telemetry.log(eventType: 'ride_stopped'));
      unawaited(_telemetry.flushPending());
    } catch (e) {
      debugPrint('AdventureCamera onRideStopped: $e');
      unawaited(
        _telemetry.log(eventType: 'error', payload: {'where': 'ride_stopped', 'error': '$e'}),
      );
    } finally {
      _telemetry.bindRide(null);
    }
  }

  Future<void> onRidePaused() async {
    unawaited(
      _telemetry.log(
        eventType: 'ride_paused',
        payload: {
          'sync_with_ride': _syncWithRide,
          'sync_pause': _syncPause,
          'zones_enabled': _zonesEnabled,
          'aggressive_enabled': _aggressiveEnabled,
          'camera_will_stop': _labEnabled && _syncWithRide && _syncPause,
          'was_recording': _controller.status.isRecording,
        },
      ),
    );
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    try {
      await _ensureStopRecording();
      unawaited(
        _telemetry.log(
          eventType: 'recording_pause',
          payload: {'reason': 'ride_auto_pause'},
        ),
      );
    } catch (e) {
      debugPrint('AdventureCamera onRidePaused: $e');
      unawaited(
        _telemetry.log(
          eventType: 'error',
          payload: {'where': 'ride_paused', 'error': '$e'},
        ),
      );
    }
  }

  Future<void> onRideResumed() async {
    final gatedByZones = _zonesEnabled && _hasStartZones;
    unawaited(
      _telemetry.log(
        eventType: 'ride_resumed',
        payload: {
          'sync_with_ride': _syncWithRide,
          'sync_pause': _syncPause,
          'zones_enabled': _zonesEnabled,
          'gated_by_start_zones': gatedByZones,
          'camera_will_resume':
              _labEnabled && _syncWithRide && _syncPause && !gatedByZones,
        },
      ),
    );
    if (!_labEnabled || !_syncWithRide || !_syncPause) return;
    // Don't resume shutter if start zones gate recording.
    if (gatedByZones) {
      unawaited(
        _telemetry.log(
          eventType: 'recording_resume_skipped',
          payload: {'reason': 'waiting_start_zone'},
        ),
      );
      return;
    }
    try {
      await _ensureStartRecording();
      unawaited(
        _telemetry.log(
          eventType: 'recording_resume',
          payload: {'reason': 'ride_auto_resume'},
        ),
      );
    } catch (e) {
      debugPrint('AdventureCamera onRideResumed: $e');
      unawaited(
        _telemetry.log(
          eventType: 'error',
          payload: {'where': 'ride_resumed', 'error': '$e'},
        ),
      );
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
      final hit = _zones.feed(latitude: latitude, longitude: longitude);
      if (hit?.action == CameraZoneAction.start) {
        unawaited(
          _telemetry.log(
            eventType: 'zone_start',
            latitude: latitude,
            longitude: longitude,
            payload: {
              'zone_id': hit!.zoneId,
              'partner_id': hit.partnerId,
            },
          ),
        );
        await _ensureConnected();
        await _ensureStartRecording();
      } else if (hit?.action == CameraZoneAction.stop) {
        unawaited(
          _telemetry.log(
            eventType: 'zone_stop',
            latitude: latitude,
            longitude: longitude,
            payload: {
              'zone_id': hit!.zoneId,
              'partner_id': hit.partnerId,
            },
          ),
        );
        await _ensureStopRecording();
        // Disconnect between clips when start zones will re-arm later.
        if (_hasStartZones) {
          await disconnect();
          _emit(
            AdventureCameraStatus(
              phase: AdventureCameraPhase.idle,
              deviceName: _status.deviceName,
              message:
                  'Stopped at zone — camera off until next start point',
              memberCount: _status.memberCount,
              readyCount: 0,
              recordingCount: 0,
            ),
          );
        }
      }
    }

    if (_aggressiveEnabled) {
      final action = _aggressive.feed(
        timestamp: now,
        leanDegrees: leanDegrees,
        speedKmh: speedKmh,
      );
      if (action == AggressiveRidingAction.start) {
        unawaited(
          _telemetry.log(
            eventType: 'aggressive_start',
            latitude: latitude,
            longitude: longitude,
            payload: {
              'lean_degrees': leanDegrees,
              'speed_kmh': speedKmh,
            },
          ),
        );
        await _ensureConnected();
        await _ensureStartRecording();
      } else if (action == AggressiveRidingAction.pause) {
        unawaited(
          _telemetry.log(
            eventType: 'aggressive_pause',
            latitude: latitude,
            longitude: longitude,
            payload: {
              'lean_degrees': leanDegrees,
              'speed_kmh': speedKmh,
            },
          ),
        );
        // Pause shutter but keep BLE ready for the next curve series.
        await _ensureStopRecording();
        _emit(
          AdventureCameraStatus(
            phase: AdventureCameraPhase.idle,
            deviceName: _status.deviceName,
            message: 'Left curve series — camera paused',
            memberCount: _status.memberCount,
            readyCount: _status.readyCount,
            recordingCount: 0,
          ),
        );
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
    final started = _controller.status.isRecording;
    unawaited(
      _telemetry.log(
        eventType: started ? 'recording_start_ok' : 'recording_start_fail',
        payload: {
          'ok': started,
          'phase': _controller.status.phase.name,
          'device': _controller.status.deviceName,
          'message': _controller.status.message,
          'recording_count': _controller.status.recordingCount,
          'member_count': _controller.status.memberCount,
          'ready_count': _controller.status.readyCount,
        },
      ),
    );
  }

  Future<void> _ensureStopRecording() async {
    if (_controller.status.phase == AdventureCameraPhase.recording ||
        _controller.status.isReady) {
      await _controller.stopRecording();
      _emit(_controller.status);
      final stopped = !_controller.status.isRecording &&
          _controller.status.phase != AdventureCameraPhase.error;
      unawaited(
        _telemetry.log(
          eventType: stopped ? 'recording_stop_ok' : 'recording_stop_fail',
          payload: {
            'ok': stopped,
            'phase': _controller.status.phase.name,
            'device': _controller.status.deviceName,
            'message': _controller.status.message,
            'recording_count': _controller.status.recordingCount,
            'member_count': _controller.status.memberCount,
          },
        ),
      );
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
