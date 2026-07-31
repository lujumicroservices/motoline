/// Connection / recording status for the experimental adventure-camera lab.
enum AdventureCameraPhase {
  disabled,
  idle,
  scanning,
  connecting,
  ready,
  recording,
  error,
}

class AdventureCameraStatus {
  const AdventureCameraStatus({
    required this.phase,
    this.deviceName,
    this.message,
  });

  final AdventureCameraPhase phase;
  final String? deviceName;
  final String? message;

  bool get isEnabled => phase != AdventureCameraPhase.disabled;
  bool get isRecording => phase == AdventureCameraPhase.recording;
  bool get isReady =>
      phase == AdventureCameraPhase.ready ||
      phase == AdventureCameraPhase.recording;

  AdventureCameraStatus copyWith({
    AdventureCameraPhase? phase,
    String? deviceName,
    String? message,
    bool clearMessage = false,
  }) {
    return AdventureCameraStatus(
      phase: phase ?? this.phase,
      deviceName: deviceName ?? this.deviceName,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  static const disabled = AdventureCameraStatus(
    phase: AdventureCameraPhase.disabled,
  );
}
