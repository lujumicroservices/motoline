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
import 'map_polyline_builder.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/speed_legend.dart';

class PilotLineMap extends StatefulWidget {
  const PilotLineMap({
    super.key,
    required this.points,
    this.height,
    this.interactive = true,
    this.allowZoom = false,
    this.showStartEnd = true,
    this.scrubIndex,
    this.onTapScrub,
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

  /// Pinch / double-tap zoom without full pan (good inside scroll views).
  final bool allowZoom;
  final bool showStartEnd;

  /// When set, a playhead marker is drawn at this sample index (into [points]).
  final int? scrubIndex;

  /// Tap near the track → absolute sample index into [points].
  final ValueChanged<int>? onTapScrub;

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
  State<PilotLineMap> createState() => _PilotLineMapState();
}

class _PilotLineMapState extends State<PilotLineMap> {
  List<Polyline> _polylines = const [];
  List<Marker> _baseMarkers = const [];
  LatLngBounds? _bounds;
  LatLng? _center;
  int? _cacheIdentity;

  @override
  void initState() {
    super.initState();
    _rebuildGeometry();
  }

  @override
  void didUpdateWidget(covariant PilotLineMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_geometryDirty(oldWidget, widget)) {
      _rebuildGeometry();
    }
  }

  bool _geometryDirty(PilotLineMap a, PilotLineMap b) {
    return !identical(a.points, b.points) ||
        !identical(a.brakeEvents, b.brakeEvents) ||
        !identical(a.roadStretches, b.roadStretches) ||
        a.focusStartIndex != b.focusStartIndex ||
        a.focusEndIndex != b.focusEndIndex ||
        a.dimOutsideFocus != b.dimOutsideFocus ||
        a.showStartEnd != b.showStartEnd ||
        a.layers.showSpeedColors != b.layers.showSpeedColors ||
        a.layers.showRoadKindContrast != b.layers.showRoadKindContrast ||
        a.layers.showBrakes != b.layers.showBrakes ||
        a.layers.showStartEnd != b.layers.showStartEnd ||
        a.layers.showLegend != b.layers.showLegend;
  }

  void _rebuildGeometry() {
    final points = widget.points;
    if (points.isEmpty) {
      _polylines = const [];
      _baseMarkers = const [];
      _bounds = null;
      _center = null;
      _cacheIdentity = 0;
      return;
    }

    final hasFocus = widget.focusStartIndex != null &&
        widget.focusEndIndex != null &&
        points.length >= 2;
    final focusLo =
        hasFocus ? widget.focusStartIndex!.clamp(0, points.length - 1) : 0;
    final focusHi = hasFocus
        ? widget.focusEndIndex!.clamp(focusLo, points.length - 1)
        : points.length - 1;

    final fitPoints =
        hasFocus ? points.sublist(focusLo, focusHi + 1) : points;
    _bounds = LatLngBounds.fromPoints([
      for (final p in fitPoints) LatLng(p.latitude, p.longitude),
    ]);
    _center = LatLng(
      fitPoints[fitPoints.length ~/ 2].latitude,
      fitPoints[fitPoints.length ~/ 2].longitude,
    );

    final kindByIndex = kindByIndexFromStretches(
      length: points.length,
      stretches: widget.roadStretches,
    );

    final polylines = <Polyline>[];
    if (hasFocus && widget.dimOutsideFocus) {
      if (focusLo > 0) {
        polylines.addAll(
          _plainSegments(points.sublist(0, focusLo + 1), dimmed: true),
        );
      }
      polylines.addAll(
        buildMergedStyledPolylines(
          segment: points.sublist(focusLo, focusHi + 1),
          indexOffset: focusLo,
          kindByIndex: kindByIndex,
          showRoadKindContrast: widget.layers.showRoadKindContrast,
          showSpeedColors: widget.layers.showSpeedColors,
        ),
      );
      if (focusHi < points.length - 1) {
        polylines.addAll(
          _plainSegments(points.sublist(focusHi, points.length), dimmed: true),
        );
      }
    } else if (hasFocus) {
      polylines.addAll(
        buildMergedStyledPolylines(
          segment: points.sublist(focusLo, focusHi + 1),
          indexOffset: focusLo,
          kindByIndex: kindByIndex,
          showRoadKindContrast: widget.layers.showRoadKindContrast,
          showSpeedColors: widget.layers.showSpeedColors,
        ),
      );
    } else {
      var cursor = 0;
      for (final segment in splitByGpsGaps(points)) {
        if (segment.length >= 2) {
          polylines.addAll(
            buildMergedStyledPolylines(
              segment: segment,
              indexOffset: cursor,
              kindByIndex: kindByIndex,
              showRoadKindContrast: widget.layers.showRoadKindContrast,
              showSpeedColors: widget.layers.showSpeedColors,
            ),
          );
        }
        cursor += segment.length;
      }
    }
    _polylines = polylines;

    final markers = <Marker>[];
    if (widget.layers.showBrakes) {
      for (final brake in widget.brakeEvents) {
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

    final showEnds = widget.layers.showStartEnd && widget.showStartEnd;
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
    _baseMarkers = markers;
    _cacheIdentity = Object.hash(
      points.length,
      focusLo,
      focusHi,
      widget.layers.showSpeedColors,
      widget.layers.showRoadKindContrast,
      widget.layers.showBrakes,
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = widget.points;
    if (points.isEmpty || _bounds == null || _center == null) {
      return Container(
        height: widget.height ?? 280,
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

    final hasFocus = widget.focusStartIndex != null &&
        widget.focusEndIndex != null &&
        points.length >= 2;

    final markers = List<Marker>.of(_baseMarkers);
    final scrub = widget.scrubIndex;
    if (widget.layers.showPlayhead &&
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
      key: ValueKey(_cacheIdentity),
      options: MapOptions(
        initialCenter: _center!,
        initialZoom: hasFocus ? 16 : 15,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : widget.allowZoom
                  ? (InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.scrollWheelZoom)
                  : InteractiveFlag.none,
        ),
        initialCameraFit: CameraFit.bounds(
          bounds: _bounds!,
          padding: const EdgeInsets.all(36),
          maxZoom: hasFocus ? 18 : 17,
        ),
        onTap: widget.onTapScrub == null
            ? null
            : (tap, latLng) {
                final idx = nearestTrackIndex(
                  points,
                  latLng.latitude,
                  latLng.longitude,
                );
                if (idx != null) widget.onTapScrub!(idx);
              },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.motoline.motoline',
        ),
        PolylineLayer(polylines: _polylines),
        MarkerLayer(markers: markers),
      ],
    );

    final stacked = Stack(
      children: [
        Positioned.fill(child: map),
        if (widget.layers.showLegend)
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
                child: widget.layers.showRoadKindContrast
                    ? _RoadKindLegend(
                        l10nRecta: l10n.recta,
                        l10nCurva: l10n.curva,
                      )
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

    if (widget.height == null) return child;
    return SizedBox(height: widget.height, child: child);
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
