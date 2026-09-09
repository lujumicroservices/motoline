import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../theme/app_theme.dart';
import 'rodada_itinerary.dart';

class RodadaItineraryStopPin {
  const RodadaItineraryStopPin({
    required this.point,
    this.title = '',
  });

  final LatLng point;
  final String title;
}

/// Tappable numbered/lettered pin for search hits or confirmed stops.
class RodadaChoiceMarker extends StatelessWidget {
  const RodadaChoiceMarker({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.asphalt, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.asphalt,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          height: 1,
        ),
      ),
    );
    if (onTap == null) return badge;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: badge,
    );
  }
}

List<Marker> rodadaSearchHitMarkers({
  required List<LatLng> points,
  required List<String> titles,
  required ValueChanged<int> onSelect,
}) {
  final n = points.length < titles.length ? points.length : titles.length;
  return [
    for (var i = 0; i < n; i++)
      Marker(
        point: points[i],
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Tooltip(
          message: titles[i],
          child: RodadaChoiceMarker(
            label: '${i + 1}',
            color: const Color(0xFF7C9CFF),
            onTap: () => onSelect(i),
          ),
        ),
      ),
  ];
}

List<Widget> rodadaItineraryMapLayers({
  LatLng? start,
  LatLng? finish,
  List<RodadaItineraryStopPin> stops = const [],
  List<LatLng>? routedLine,
}) {
  final pins = rodadaItineraryLine(
    start: start,
    stops: [for (final s in stops) s.point],
    finish: finish,
  );
  final line = rodadaDisplayLine(pins: pins, routed: routedLine);
  return [
    if (line.length >= 2)
      PolylineLayer(
        polylines: [
          Polyline(
            points: line,
            color: AppTheme.line.withValues(alpha: 0.85),
            strokeWidth: 3,
          ),
        ],
      ),
    MarkerLayer(
      markers: [
        if (start != null)
          Marker(
            point: start,
            width: 40,
            height: 40,
            child: const Icon(Icons.flag, color: AppTheme.lineHot, size: 32),
          ),
        for (var i = 0; i < stops.length; i++)
          Marker(
            point: stops[i].point,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Tooltip(
              message: stops[i].title,
              child: RodadaChoiceMarker(
                label: rodadaStopLetter(i),
                color: AppTheme.signal,
              ),
            ),
          ),
        if (finish != null)
          Marker(
            point: finish,
            width: 40,
            height: 40,
            child: const Icon(
              Icons.sports_score,
              color: AppTheme.line,
              size: 32,
            ),
          ),
      ],
    ),
  ];
}

LatLngBounds? rodadaItineraryBounds(List<LatLng> points) {
  if (points.isEmpty) return null;
  if (points.length == 1) {
    final p = points.first;
    return LatLngBounds.fromPoints([
      LatLng(p.latitude - 0.01, p.longitude - 0.01),
      LatLng(p.latitude + 0.01, p.longitude + 0.01),
    ]);
  }
  return LatLngBounds.fromPoints(points);
}
