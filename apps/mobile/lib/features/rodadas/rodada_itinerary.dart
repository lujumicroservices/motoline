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

/// Title from selected pins: `"Guadalajara - Tapalpa"`.
String rodadaAutoTitle({
  required String startName,
  required String finishName,
}) {
  final start = startName.trim();
  final finish = finishName.trim();
  if (start.isEmpty) return finish;
  if (finish.isEmpty) return start;
  return '$start - $finish';
}

/// Waypoints for routing. [roundTrip] appends the reverse so Valhalla
/// traces the same itinerary back to start.
List<LatLng> rodadaRouteWaypoints({
  LatLng? start,
  List<LatLng> stops = const [],
  LatLng? finish,
  bool roundTrip = false,
}) {
  final outbound = rodadaItineraryLine(
    start: start,
    stops: stops,
    finish: finish,
  );
  if (!roundTrip || outbound.length < 2) return outbound;
  return [
    ...outbound,
    for (var i = outbound.length - 2; i >= 0; i--) outbound[i],
  ];
}

/// A, B, C… for stop markers (start/finish keep their own icons).
String rodadaStopLetter(int zeroBasedIndex) {
  if (zeroBasedIndex < 0) return '';
  if (zeroBasedIndex < 26) {
    return String.fromCharCode(65 + zeroBasedIndex);
  }
  return '${zeroBasedIndex + 1}';
}
