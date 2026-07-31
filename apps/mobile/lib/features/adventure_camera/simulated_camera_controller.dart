import 'dart:async';

import 'package:flutter/foundation.dart';

import 'camera_controller.dart';
import 'models/adventure_camera_status.dart';

/// Dev-only shutter that fakes a camera — no BLE hardware required.
class SimulatedCameraController implements AdventureCameraController {
  SimulatedCameraController()
      : _controller = StreamController<AdventureCameraStatus>.broadcast() {
    _emit(
      const AdventureCameraStatus(
        phase: AdventureCameraPhase.ready,
        deviceName: 'Simulated cam',
        message: 'Lab simulator — no hardware',
      ),
    );
  }

  final StreamController<AdventureCameraStatus> _controller;
  AdventureCameraStatus _status = AdventureCameraStatus.disabled;

  @override
  String get backendId => 'simulated';

  @override
  Stream<AdventureCameraStatus> get statusStream => _controller.stream;

  @override
  AdventureCameraStatus get status => _status;

  @override
  Future<void> ensurePermissions() async {}

  @override
  Future<void> connect({String? preferredDeviceId}) async {
    _emit(
      const AdventureCameraStatus(
        phase: AdventureCameraPhase.ready,
        deviceName: 'Simulated cam',
        message: 'Lab simulator ready',
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _emit(
      const AdventureCameraStatus(
        phase: AdventureCameraPhase.idle,
        deviceName: 'Simulated cam',
      ),
    );
  }

  @override
  Future<void> startRecording() async {
    debugPrint('AdventureCamera[sim]: START recording');
    _emit(
      const AdventureCameraStatus(
        phase: AdventureCameraPhase.recording,
        deviceName: 'Simulated cam',
        message: 'Sim recording',
      ),
    );
  }

  @override
  Future<void> stopRecording() async {
    debugPrint('AdventureCamera[sim]: STOP recording');
    _emit(
      const AdventureCameraStatus(
        phase: AdventureCameraPhase.ready,
        deviceName: 'Simulated cam',
        message: 'Sim idle',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void _emit(AdventureCameraStatus next) {
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }
}
