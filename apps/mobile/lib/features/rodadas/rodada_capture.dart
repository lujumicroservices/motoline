import '../../core/models/ride.dart';

bool rideIsRodadaBound(Ride? ride) {
  final id = ride?.rodadaId;
  return id != null && id.isNotEmpty;
}

/// Incomplete garage banner: hide rodada-bound recording until the outing ends.
bool shouldHideIncompleteRodadaRide(Ride? incomplete) =>
    rideIsRodadaBound(incomplete);

bool shouldUseRodadaPauseAction(String? activeRodadaId) {
  final id = activeRodadaId;
  return id != null && id.isNotEmpty;
}

bool isActivelyCapturingRodada({
  required String rodadaId,
  required String? activeRodadaId,
  required bool isRecording,
  required bool metricsHeld,
}) {
  if (activeRodadaId != rodadaId) return false;
  return isRecording && !metricsHeld;
}

bool shouldShowResumeRodadaCapture({
  required bool rodadaLive,
  required String rodadaId,
  required String? activeRodadaId,
  required bool isRecording,
  required bool isArmed,
  required bool metricsHeld,
  required bool hasLocalRecordingRide,
}) {
  if (!rodadaLive) return false;
  final bound = activeRodadaId == rodadaId || hasLocalRecordingRide;
  if (!bound) return false;
  if (isActivelyCapturingRodada(
    rodadaId: rodadaId,
    activeRodadaId: activeRodadaId,
    isRecording: isRecording,
    metricsHeld: metricsHeld,
  )) {
    return false;
  }
  return metricsHeld ||
      hasLocalRecordingRide ||
      isArmed ||
      activeRodadaId == rodadaId;
}
