import '../../core/lean_lab/lean_lab_circuit.dart';
import '../../core/lean_lab/lean_lab_models.dart';

/// Passed into [ActiveRideScreen] so a Lean Lab session attaches after start.
class LeanLabRideBootstrap {
  const LeanLabRideBootstrap({
    required this.sessionType,
    required this.direction,
    required this.phoneMount,
    required this.phonePose,
    required this.frozenNeutralDeg,
    this.calibAt,
  });

  final LeanLabSessionType sessionType;
  final LeanLabDirection direction;
  final String phoneMount;
  final PhonePoseId phonePose;
  final double frozenNeutralDeg;
  final DateTime? calibAt;
}
