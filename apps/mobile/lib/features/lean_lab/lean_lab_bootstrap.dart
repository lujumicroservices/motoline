import '../../core/lean_lab/lean_imu_math.dart';
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
    this.frozenG0,
    this.signFlip = 1,
    this.calibAt,
  });

  final LeanLabSessionType sessionType;
  final LeanLabDirection direction;
  final String phoneMount;
  final PhonePoseId phonePose;

  /// Always 0 with the vector engine (lean is already relative to g0).
  final double frozenNeutralDeg;
  final Vec3? frozenG0;
  final int signFlip;
  final DateTime? calibAt;
}
