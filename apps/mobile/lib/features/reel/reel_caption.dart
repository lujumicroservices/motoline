String buildReelCaption({
  required String destination,
  required double distanceKm,
  required double maxLeanDeg,
  required int curveCount,
  required int riderCount,
  required String cta,
}) {
  final dest = destination.trim().isEmpty ? 'Rodada' : destination.trim();
  return '$dest · ${distanceKm.toStringAsFixed(1)} km · '
      '${maxLeanDeg.round()}° · $curveCount curvas · $riderCount riders\n'
      '$cta\n'
      '#RiderLab #Rodada #Moto';
}
