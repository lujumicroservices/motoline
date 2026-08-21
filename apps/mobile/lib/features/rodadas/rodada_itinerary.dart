import 'package:latlong2/latlong.dart';

enum RodadaPinMode { start, finish, stop }

class DraftRodadaStop {
  const DraftRodadaStop({required this.point, required this.title});

  final LatLng point;
  final String title;
}

/// Straight itinerary (not routed): start → stops → finish, skipping nulls.
List<LatLng> rodadaItineraryLine({
  LatLng? start,
  List<LatLng> stops = const [],
  LatLng? finish,
}) {
  return [
    ?start,
    ...stops,
    ?finish,
  ];
}

/// Prefer a snapped route; fall back to pin-to-pin when routing failed.
List<LatLng> rodadaDisplayLine({
  required List<LatLng> pins,
  List<LatLng>? routed,
}) {
  if (routed != null && routed.length >= 2) return routed;
  return pins;
}

/// Next `rodada_stops.sort_order` after the current set (empty → 0).
int nextStopSortOrder(Iterable<int> existing) {
  var max = -1;
  for (final n in existing) {
    if (n > max) max = n;
  }
  return max + 1;
}
