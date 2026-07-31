import 'dart:async';

import 'camera_controller.dart';
import 'models/adventure_camera_status.dart';

/// No-op backend when the lab feature is off.
class NoopCameraController implements AdventureCameraController {
  NoopCameraController()
      : _controller = StreamController<AdventureCameraStatus>.broadcast();

  final StreamController<AdventureCameraStatus> _controller;
  AdventureCameraStatus _status = AdventureCameraStatus.disabled;

  @override
  String get backendId => 'noop';

  @override
  Stream<AdventureCameraStatus> get statusStream => _controller.stream;

  @override
  AdventureCameraStatus get status => _status;

  @override
  Future<void> ensurePermissions() async {}

  @override
  Future<void> connect({String? preferredDeviceId}) async {
    _emit(AdventureCameraStatus.disabled);
  }

  @override
  Future<void> disconnect() async {
    _emit(AdventureCameraStatus.disabled);
  }

  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  void _emit(AdventureCameraStatus next) {
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }
}
