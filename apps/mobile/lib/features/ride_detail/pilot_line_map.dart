import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import 'widgets/map_layer_toggles.dart';
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
    this.roadStretches = const [],
    this.layers = const MapLayerOptions(),
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

  /// Recta/curva stretches for high-contrast road-kind coloring.
  final List<RoadStretch> roadStretches;

  final MapLayerOptions layers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (points.isEmpty) {
      return Container(
        height: height ?? 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          l10n.noGpsPoints,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.steel),
        ),
      );
    }

    final hasFocus = focusStartIndex != null &&
        focusEndIndex != null &&
        points.length >= 2;
    final focusLo =
        hasFocus ? focusStartIndex!.clamp(0, points.length - 1) : 0;
    final focusHi = hasFocus
        ? focusEndIndex!.clamp(focusLo, points.length - 1)
        : points.length - 1;

    final fitPoints =
        hasFocus ? points.sublist(focusLo, focusHi + 1) : points;
    final bounds = LatLngBounds.fromPoints(
      fitPoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );
    final center = LatLng(
      fitPoints[fitPoints.length ~/ 2].latitude,
      fitPoints[fitPoints.length ~/ 2].longitude,
    );

    final kindByIndex = _kindByIndex(points.length, roadStretches);

    final polylines = <Polyline>[];
    if (hasFocus && dimOutsideFocus) {
      if (focusLo > 0) {
        polylines.addAll(
          _plainSegments(points.sublist(0, focusLo + 1), dimmed: true),
        );
      }
      polylines.addAll(
        _lineSegments(
          points.sublist(focusLo, focusHi + 1),
          indexOffset: focusLo,
          kindByIndex: kindByIndex,
        ),
      );
      if (focusHi < points.length - 1) {
        polylines.addAll(
          _plainSegments(points.sublist(focusHi, points.length), dimmed: true),
        );
      }
    } else if (hasFocus) {
      polylines.addAll(
        _lineSegments(
          points.sublist(focusLo, focusHi + 1),
          indexOffset: focusLo,
          kindByIndex: kindByIndex,
        ),
      );
    } else {
      final segments = splitByGpsGaps(points);
      var cursor = 0;
      for (final segment in segments) {
        if (segment.length >= 2) {
          polylines.addAll(
            _lineSegments(
              segment,
              indexOffset: cursor,
              kindByIndex: kindByIndex,
            ),
          );
        }
        cursor += segment.length;
      }
    }

    final markers = <Marker>[];
    if (layers.showBrakes) {
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
              child:
                  const Icon(Icons.south, size: 12, color: AppTheme.asphalt),
            ),
          ),
        );
      }
    }

    final showEnds = layers.showStartEnd && showStartEnd;
    if (showEnds && fitPoints.isNotEmpty) {
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
    if (layers.showPlayhead &&
        scrub != null &&
        scrub >= 0 &&
        scrub < points.length) {
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
        if (layers.showLegend)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xCC1A1C1E),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: layers.showRoadKindContrast
                    ? _RoadKindLegend(l10nRecta: l10n.recta, l10nCurva: l10n.curva)
                    : const SpeedColorLegend(),
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

  List<(RoadKind kind, TurnSide side)?> _kindByIndex(
    int length,
    List<RoadStretch> stretches,
  ) {
    final out = List<(RoadKind, TurnSide)?>.filled(length, null);
    for (final s in stretches) {
      final lo = s.startIndex.clamp(0, length - 1);
      final hi = s.endIndex.clamp(lo, length - 1);
      for (var i = lo; i <= hi; i++) {
        out[i] = (s.kind, s.side);
      }
    }
    return out;
  }

  List<Polyline> _lineSegments(
    List<TrackPoint> segment, {
    required int indexOffset,
    required List<(RoadKind kind, TurnSide side)?> kindByIndex,
  }) {
    final result = <Polyline>[];
    for (var i = 1; i < segment.length; i++) {
      final a = segment[i - 1];
      final b = segment[i];
      final absIndex = indexOffset + i;
      final style = _strokeForIndex(absIndex, b, kindByIndex);
      result.add(
        Polyline(
          points: [
            LatLng(a.latitude, a.longitude),
            LatLng(b.latitude, b.longitude),
          ],
          color: style.$1,
          strokeWidth: style.$2,
        ),
      );
    }
    return result;
  }

  (Color, double) _strokeForIndex(
    int absIndex,
    TrackPoint b,
    List<(RoadKind kind, TurnSide side)?> kindByIndex,
  ) {
    // Road-kind contrast wins when on — stronger curves vs muted straights.
    if (layers.showRoadKindContrast &&
        absIndex >= 0 &&
        absIndex < kindByIndex.length) {
      final kind = kindByIndex[absIndex];
      if (kind != null) {
        if (kind.$1 == RoadKind.recta) {
          return (RideVizPalette.roadRecta.withValues(alpha: 0.75), 3.5);
        }
        final color = switch (kind.$2) {
          TurnSide.izquierda => RideVizPalette.roadCurvaLeft,
          TurnSide.derecha => RideVizPalette.roadCurvaRight,
          TurnSide.none => RideVizPalette.roadCurva,
        };
        return (color, 7);
      }
    }

    if (layers.showSpeedColors) {
      final speed = b.speedKmh ?? 0;
      return (RideVizPalette.speedColor(speed), 5);
    }

    return (AppTheme.mist.withValues(alpha: 0.85), 4);
  }

  List<Polyline> _plainSegments(
    List<TrackPoint> segment, {
    required bool dimmed,
  }) {
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

class _RoadKindLegend extends StatelessWidget {
  const _RoadKindLegend({
    required this.l10nRecta,
    required this.l10nCurva,
  });

  final String l10nRecta;
  final String l10nCurva;

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: AppTheme.steel, fontSize: 11),
            ),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        item(RideVizPalette.roadRecta, l10nRecta),
        item(RideVizPalette.roadCurva, l10nCurva),
        item(RideVizPalette.roadCurvaLeft, '←'),
        item(RideVizPalette.roadCurvaRight, '→'),
      ],
    );
  }
}
