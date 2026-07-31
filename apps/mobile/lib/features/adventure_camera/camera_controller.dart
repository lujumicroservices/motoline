import 'models/adventure_camera_status.dart';

/// Vendor-agnostic shutter control (GoPro today, Insta360 later).
abstract class AdventureCameraController {
  String get backendId;

  Stream<AdventureCameraStatus> get statusStream;

  AdventureCameraStatus get status;

  Future<void> ensurePermissions();

  /// Scan + connect (or reconnect to last device).
  Future<void> connect({String? preferredDeviceId});

  Future<void> disconnect();

  Future<void> startRecording();

  Future<void> stopRecording();

  Future<void> dispose();
}
