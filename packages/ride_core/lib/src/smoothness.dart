/// Simple smoothness score from successive speed samples (m/s).
///
/// Returns 0–100 where higher = smoother (lower jerk / variance).
double smoothnessScoreFromSpeeds(List<double?> speedsMps) {
  final speeds = <double>[
    for (final s in speedsMps)
      if (s != null && s.isFinite && s >= 0) s,
  ];
  if (speeds.length < 3) return 100;

  var sumDelta = 0.0;
  var count = 0;
  for (var i = 1; i < speeds.length; i++) {
    sumDelta += (speeds[i] - speeds[i - 1]).abs();
    count++;
  }
  final meanJerk = sumDelta / count;
  // ~0.5 m/s² mean change → still good; 3+ feels harsh for street.
  final penalty = (meanJerk / 3.0).clamp(0.0, 1.0);
  return ((1.0 - penalty) * 100).clamp(0.0, 100.0);
}

/// Entry consistency: how close entry speeds stay across similar corners.
/// [entrySpeedsMps] are peak-entry samples for comparable corners.
double entryConsistencyScore(List<double> entrySpeedsMps) {
  if (entrySpeedsMps.length < 2) return 100;
  final mean =
      entrySpeedsMps.reduce((a, b) => a + b) / entrySpeedsMps.length;
  if (mean <= 0.1) return 100;
  var sumSq = 0.0;
  for (final s in entrySpeedsMps) {
    final d = (s - mean) / mean;
    sumSq += d * d;
  }
  final cv = (sumSq / entrySpeedsMps.length).clamp(0.0, 1.0);
  return ((1.0 - cv) * 100).clamp(0.0, 100.0);
}
