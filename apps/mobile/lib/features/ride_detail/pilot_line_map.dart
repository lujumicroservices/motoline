import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import 'widgets/speed_legend.dart';

class PilotLineMap extends StatelessWidget {
  const PilotLineMap({
    super.key,
    required this.points,
    this.height,
    this.interactive = true,
    this.showStartEnd = true,
    this.scrubIndex,
    this.focusStartIndex,
    this.focusEndIndex,
    this.dimOutsideFocus = true,
    this.brakeEvents = const [],
  });

  final List<TrackPoint> points;
  final double? height;
  final bool interactive;
  final bool showStartEnd;

  /// When set, a playhead marker is drawn at this sample index (into [points]).
  final int? scrubIndex;

  /// Inclusive focus window into [points] for segment zoom.
  final int? focusStartIndex;
  final int? focusEndIndex;

  /// When focusing, draw the rest of the line dimmed.
  final bool dimOutsideFocus;

  /// Brake hits inferred from speed — drawn as map pins.
  final List<BrakeEvent> brakeEvents;

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

    final hasFocus = focusStartIndex != null &&
        focusEndIndex != null &&
        points.length >= 2;
    final focusLo = hasFocus
        ? focusStartIndex!.clamp(0, points.length - 1)
        : 0;
    final focusHi = hasFocus
        ? focusEndIndex!.clamp(focusLo, points.length - 1)
        : points.length - 1;

    final fitPoints = hasFocus
        ? points.sublist(focusLo, focusHi + 1)
        : points;
    final bounds = LatLngBounds.fromPoints(
      fitPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
    final center = LatLng(
      fitPoints[fitPoints.length ~/ 2].latitude,
      fitPoints[fitPoints.length ~/ 2].longitude,
    );

    final polylines = <Polyline>[];
    if (hasFocus && dimOutsideFocus) {
      if (focusLo > 0) {
        polylines.addAll(
          _plainSegments(points.sublist(0, focusLo + 1), dimmed: true),
        );
      }
      polylines.addAll(
        _coloredSegments(points.sublist(focusLo, focusHi + 1)),
      );
      if (focusHi < points.length - 1) {
        polylines.addAll(
          _plainSegments(points.sublist(focusHi, points.length), dimmed: true),
        );
      }
    } else if (hasFocus) {
      polylines.addAll(
        _coloredSegments(points.sublist(focusLo, focusHi + 1)),
      );
    } else {
      final segments = splitByGpsGaps(points);
      for (final segment in segments) {
        if (segment.length < 2) continue;
        polylines.addAll(_coloredSegments(segment));
      }
    }

    final markers = <Marker>[];
    for (final brake in brakeEvents) {
      final mid = ((brake.startIndex + brake.endIndex) / 2).round();
      if (mid < 0 || mid >= points.length) continue;
      if (hasFocus && (mid < focusLo || mid > focusHi)) continue;
      final p = points[mid];
      final color = RideVizPalette.brakeColor(brake.hardness);
      markers.add(
        Marker(
          point: LatLng(p.latitude, p.longitude),
          width: 22,
          height: 22,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.asphalt, width: 2),
            ),
            child: const Icon(Icons.south, size: 12, color: AppTheme.asphalt),
          ),
        ),
      );
    }

    if (showStartEnd && fitPoints.isNotEmpty) {
      markers.add(
        Marker(
          point: LatLng(fitPoints.first.latitude, fitPoints.first.longitude),
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
          point: LatLng(fitPoints.last.latitude, fitPoints.last.longitude),
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
            child:
                const Icon(Icons.navigation, size: 14, color: AppTheme.asphalt),
          ),
        ),
      );
    }

    final map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: hasFocus ? 16 : 15,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(36),
          maxZoom: hasFocus ? 18 : 17,
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

    final stacked = Stack(
      children: [
        Positioned.fill(child: map),
        const Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xCC1A1C1E),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: SpeedColorLegend(),
            ),
          ),
        ),
      ],
    );

    final child = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: stacked,
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
          color: RideVizPalette.speedColor(speed),
          strokeWidth: 5,
        ),
      );
    }
    return result;
  }

  List<Polyline> _plainSegments(List<TrackPoint> segment, {required bool dimmed}) {
    if (segment.length < 2) return const [];
    return [
      Polyline(
        points: [
          for (final p in segment) LatLng(p.latitude, p.longitude),
        ],
        color: AppTheme.steel.withValues(alpha: dimmed ? 0.35 : 0.7),
        strokeWidth: dimmed ? 3 : 4,
      ),
    ];
  }
}
