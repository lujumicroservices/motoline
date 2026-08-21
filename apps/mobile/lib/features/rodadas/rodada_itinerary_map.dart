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

List<Widget> rodadaItineraryMapLayers({
  LatLng? start,
  LatLng? finish,
  List<RodadaItineraryStopPin> stops = const [],
}) {
  final line = rodadaItineraryLine(
    start: start,
    stops: [for (final s in stops) s.point],
    finish: finish,
  );
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
        for (final s in stops)
          Marker(
            point: s.point,
            width: 40,
            height: 40,
            child: Tooltip(
              message: s.title,
              child: const Icon(
                Icons.local_gas_station,
                color: AppTheme.signal,
                size: 30,
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
