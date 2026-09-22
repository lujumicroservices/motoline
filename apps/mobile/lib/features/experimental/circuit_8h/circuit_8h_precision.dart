import '../../../core/services/location_service.dart';

/// Horizontal gate for Circuito 8h survey fixes only.
///
/// Ride recording still accepts up to [LocationService.maxAcceptAccuracyMeters]
/// (40 m) so a canyon does not punch a hole in a normal line. This lab stores
/// a calibration track, so a 15–40 m fix would bend the circuit.
///
/// The stream already asks for navigation accuracy at ~10 Hz with no
/// distance filter. Phone fused GNSS cannot deliver centimeters; that needs
/// an external receiver or RTK. 8 m keeps open-sky multi-band fixes and
/// drops the loose ones Android still reports as valid.
const circuit8hMaxAcceptAccuracyMeters = 8.0;

enum Circuit8hFixDrop { accuracy, teleport }

class Circuit8hFixDecision {
  const Circuit8hFixDecision.accept() : drop = null;

  const Circuit8hFixDecision.drop(this.drop);

  final Circuit8hFixDrop? drop;

  bool get accepted => drop == null;
}

/// Keep a survey fix only when reported accuracy is tight and the hop from
/// the previous stored point is still a motorcycle move.
///
/// Pass null jump/dt for the first point or for a marker (no path yet).
Circuit8hFixDecision decideCircuit8hFix({
  required double? accuracyMeters,
  double? jumpMeters,
  double? dtSeconds,
  double maxAccuracyMeters = circuit8hMaxAcceptAccuracyMeters,
}) {
  if (accuracyMeters == null ||
      !accuracyMeters.isFinite ||
      accuracyMeters <= 0 ||
      accuracyMeters > maxAccuracyMeters) {
    return const Circuit8hFixDecision.drop(Circuit8hFixDrop.accuracy);
  }

  if (jumpMeters != null && dtSeconds != null) {
    final maxJump = maxPlausibleJumpMeters(
      dtSeconds: dtSeconds,
      accuracyMeters: accuracyMeters,
      previousAccuracyMeters: maxAccuracyMeters,
    );
    final verdict = classifyGpsJump(
      jumpMeters: jumpMeters,
      dtSeconds: dtSeconds,
      maxJumpMeters: maxJump,
    );
    if (verdict == GpsJumpVerdict.teleport) {
      return const Circuit8hFixDecision.drop(Circuit8hFixDrop.teleport);
    }
  }

  return const Circuit8hFixDecision.accept();
}
