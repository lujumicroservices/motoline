import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../theme/app_theme.dart';

class PilotLineMap extends StatelessWidget {
  const PilotLineMap({
    super.key,
    required this.points,
    this.height,
    this.interactive = true,
    this.showStartEnd = true,
    this.scrubIndex,
  });

  final List<TrackPoint> points;
  final double? height;
  final bool interactive;
  final bool showStartEnd;

  /// When set, a playhead marker is drawn at this sample index.
  final int? scrubIndex;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: height ?? 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'No GPS points yet — your line will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.steel),
        ),
      );
    }

    final segments = splitByGpsGaps(points);
    final bounds = LatLngBounds.fromPoints(
      points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
    final center = LatLng(
      points[points.length ~/ 2].latitude,
      points[points.length ~/ 2].longitude,
    );

    final polylines = <Polyline>[];
    for (final segment in segments) {
      if (segment.length < 2) continue;
      polylines.addAll(_coloredSegments(segment));
    }

    final markers = <Marker>[];
    if (showStartEnd && points.isNotEmpty) {
      markers.add(
        Marker(
          point: LatLng(points.first.latitude, points.first.longitude),
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.line,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.mist, width: 2),
            ),
          ),
        ),
      );
      markers.add(
        Marker(
          point: LatLng(points.last.latitude, points.last.longitude),
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.signal,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.mist, width: 2),
            ),
          ),
        ),
      );
    }

    final scrub = scrubIndex;
    if (scrub != null && scrub >= 0 && scrub < points.length) {
      final p = points[scrub];
      markers.add(
        Marker(
          point: LatLng(p.latitude, p.longitude),
          width: 28,
          height: 28,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.mist,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.lineHot, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.lineHot.withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, size: 14, color: AppTheme.asphalt),
          ),
        ),
      );
    }

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(36),
          maxZoom: 17,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.motoline.motoline',
        ),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: map,
    );

    if (height == null) return child;
    return SizedBox(height: height, child: child);
  }

  List<Polyline> _coloredSegments(List<TrackPoint> segment) {
    final result = <Polyline>[];
    for (var i = 1; i < segment.length; i++) {
      final a = segment[i - 1];
      final b = segment[i];
      final speed = b.speedKmh ?? a.speedKmh ?? 0;
      result.add(
        Polyline(
          points: [
            LatLng(a.latitude, a.longitude),
            LatLng(b.latitude, b.longitude),
          ],
          color: _speedColor(speed),
          strokeWidth: 5,
        ),
      );
    }
    return result;
  }

  Color _speedColor(double speedKmh) {
    if (speedKmh < 30) return AppTheme.line;
    if (speedKmh < 70) return AppTheme.lineHot;
    return AppTheme.signal;
  }
}
