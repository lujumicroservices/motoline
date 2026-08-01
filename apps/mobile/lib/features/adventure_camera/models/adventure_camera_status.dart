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
    this.memberCount,
    this.readyCount,
    this.recordingCount,
  });

  final AdventureCameraPhase phase;
  final String? deviceName;
  final String? message;

  /// Enabled cameras in the group (null when single-cam / unknown).
  final int? memberCount;
  final int? readyCount;
  final int? recordingCount;

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
    int? memberCount,
    int? readyCount,
    int? recordingCount,
  }) {
    return AdventureCameraStatus(
      phase: phase ?? this.phase,
      deviceName: deviceName ?? this.deviceName,
      message: clearMessage ? null : (message ?? this.message),
      memberCount: memberCount ?? this.memberCount,
      readyCount: readyCount ?? this.readyCount,
      recordingCount: recordingCount ?? this.recordingCount,
    );
  }

  static const disabled = AdventureCameraStatus(
    phase: AdventureCameraPhase.disabled,
  );
}
