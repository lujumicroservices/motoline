import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../maps/live_gps_map_mixin.dart';
import '../maps/map_control_chip.dart';
import 'map_polyline_builder.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/speed_legend.dart';

/// Result returned when the rider loads metrics for a map area.
class FullscreenMapSelection {
  const FullscreenMapSelection({
    required this.startIndex,
    required this.endIndex,
  });

  final int startIndex;
  final int endIndex;
}

/// Full-screen pilot line: navigate, select an area, load metrics for it.
class FullscreenMapScreen extends StatefulWidget {
  const FullscreenMapScreen({
    super.key,
    required this.points,
    this.scrubIndex,
    this.brakeEvents = const [],
    this.roadStretches = const [],
    this.initialLayers = const MapLayerOptions(),
    this.initialFocusStart,
    this.initialFocusEnd,
  });

  final List<TrackPoint> points;
  final int? scrubIndex;
  final List<BrakeEvent> brakeEvents;
  final List<RoadStretch> roadStretches;
  final MapLayerOptions initialLayers;
  final int? initialFocusStart;
  final int? initialFocusEnd;

  @override
  State<FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<FullscreenMapScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();

  /// Selection-rect drag only — avoids rebuilding the track on every pan frame.
  final ValueNotifier<(Offset?, Offset?)> _dragRect =
      ValueNotifier<(Offset?, Offset?)>((null, null));

  bool _selectMode = false;
  LatLngBounds? _areaBounds;
  ({int start, int end, int insideCount})? _selection;
  late MapLayerOptions _layers;
  late int _scrubIndex;

  LatLngBounds? _rideBounds;
  LatLng? _rideCenter;
  List<Polyline> _polylines = const [];
  List<Marker> _markers = const [];

  @override
  void initState() {
    super.initState();
    _layers = widget.initialLayers;
    final scrub = widget.scrubIndex;
    _scrubIndex = scrub != null &&
            scrub >= 0 &&
            scrub < widget.points.length
        ? scrub
        : (widget.points.isEmpty ? 0 : widget.points.length ~/ 2);
    final lo = widget.initialFocusStart;
    final hi = widget.initialFocusEnd;
    if (lo != null &&
        hi != null &&
        hi > lo &&
        hi < widget.points.length &&
        lo >= 0) {
      _selection = (start: lo, end: hi, insideCount: hi - lo + 1);
      final slice = widget.points.sublist(lo, hi + 1);
      if (slice.length >= 2) {
        _areaBounds = LatLngBounds.fromPoints([
          for (final p in slice) LatLng(p.latitude, p.longitude),
        ]);
      }
    }
    _rebuildTrackLayers();
  }

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    _dragRect.dispose();
    super.dispose();
  }

  void _rebuildTrackLayers() {
    final points = widget.points;
    if (points.isEmpty) {
      _rideBounds = null;
      _rideCenter = null;
      _polylines = const [];
      _markers = const [];
      return;
    }
    _rideBounds = LatLngBounds.fromPoints([
      for (final p in points) LatLng(p.latitude, p.longitude),
    ]);
    _rideCenter = LatLng(
      points[points.length ~/ 2].latitude,
      points[points.length ~/ 2].longitude,
    );
    _polylines = _buildPolylines(
      points,
      focusLo: _selection?.start,
      focusHi: _selection?.end,
    );
    _markers = _buildMarkers(
      points,
      focusLo: _selection?.start,
      focusHi: _selection?.end,
    );
  }

  void _fitRide() {
    if (widget.points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([
      for (final p in widget.points) LatLng(p.latitude, p.longitude),
    ]);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 200),
        maxZoom: 17,
      ),
    );
  }

  void _fitSelection(int start, int end) {
    if (end <= start || end >= widget.points.length) return;
    final slice = widget.points.sublist(start, end + 1);
    if (slice.length < 2) return;
    final bounds = LatLngBounds.fromPoints([
      for (final p in slice) LatLng(p.latitude, p.longitude),
    ]);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 140, 48, 220),
        maxZoom: 18,
      ),
    );
  }

  void _zoomBy(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
  }

  /// Slightly expand a drawn/visible box so edge GPS samples still count.
  LatLngBounds _padBounds(LatLngBounds bounds, {double padDeg = 0.00012}) {
    return LatLngBounds(
      LatLng(bounds.south - padDeg, bounds.west - padDeg),
      LatLng(bounds.north + padDeg, bounds.east + padDeg),
    );
  }

  void _applyBounds(LatLngBounds raw, {bool showFeedback = true}) {
    final bounds = _padBounds(raw);
    final center = LatLng(
      (bounds.north + bounds.south) / 2,
      (bounds.east + bounds.west) / 2,
    );
    final hit = segmentIndicesInBounds(
      points: widget.points,
      isInside: (p) => bounds.contains(LatLng(p.latitude, p.longitude)),
      preferLat: center.latitude,
      preferLng: center.longitude,
    );
    _dragRect.value = (null, null);
    setState(() {
      _areaBounds = bounds;
      _selection = hit;
      _rebuildTrackLayers();
    });
    if (hit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitSelection(hit.start, hit.end);
      });
    } else if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.areaNoPoints)),
      );
    }
  }

  void _useVisibleArea() {
    // Shrink visible camera slightly so chrome/edges don't pull the whole ride.
    final vis = _map.camera.visibleBounds;
    final latPad = (vis.north - vis.south) * 0.08;
    final lngPad = (vis.east - vis.west) * 0.08;
    final inset = LatLngBounds(
      LatLng(vis.south + latPad, vis.west + lngPad),
      LatLng(vis.north - latPad, vis.east - lngPad),
    );
    _applyBounds(inset);
  }

  void _onSelectPanStart(DragStartDetails details) {
    _dragRect.value = (details.localPosition, details.localPosition);
  }

  void _onSelectPanUpdate(DragUpdateDetails details) {
    final start = _dragRect.value.$1;
    _dragRect.value = (start, details.localPosition);
  }

  void _onSelectPanEnd(DragEndDetails details) {
    final a = _dragRect.value.$1;
    final b = _dragRect.value.$2;
    if (a == null || b == null) return;
    if ((a - b).distance < 24) {
      _dragRect.value = (null, null);
      return;
    }
    final cam = _map.camera;
    final p1 = cam.screenOffsetToLatLng(a);
    final p2 = cam.screenOffsetToLatLng(b);
    _applyBounds(LatLngBounds(p1, p2));
  }

  void _clearSelection() {
    _dragRect.value = (null, null);
    setState(() {
      _areaBounds = null;
      _selection = null;
      _rebuildTrackLayers();
    });
  }

  void _loadMetrics() {
    final sel = _selection;
    if (sel == null || sel.end <= sel.start) return;
    Navigator.of(context).pop(
      FullscreenMapSelection(startIndex: sel.start, endIndex: sel.end),
    );
  }

  void _setScrubAt(LatLng latLng) {
    if (_selectMode) return;
    final idx = nearestTrackIndex(
      widget.points,
      latLng.latitude,
      latLng.longitude,
    );
    if (idx == null || idx == _scrubIndex) return;
    setState(() {
      _scrubIndex = idx;
      _rebuildTrackLayers();
    });
  }

  void _popWithScrub() {
    Navigator.of(context).pop(_scrubIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = widget.points;

    if (points.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.fullscreenMap)),
        body: Center(child: Text(l10n.noGpsPoints)),
      );
    }

    final focusLo = _selection?.start;
    final focusHi = _selection?.end;
    final hasFocus = focusLo != null && focusHi != null;
    final bounds = _rideBounds!;
    final center = _rideCenter!;
    final scrubPoint = widget.points[_scrubIndex.clamp(0, points.length - 1)];
    final lean = scrubPoint.leanDegrees ?? 0.0;
    final speed = scrubPoint.speedKmh;
    final leanSide = lean < -1
        ? l10n.leftShort
        : lean > 1
            ? l10n.rightShort
            : '·';

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _popWithScrub();
        },
        child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.fromLTRB(48, 120, 48, 200),
                  maxZoom: 17,
                ),
                interactionOptions: InteractionOptions(
                  flags: _selectMode
                      ? InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom
                      : InteractiveFlag.all,
                ),
                onTap: _selectMode ? null : (tap, latLng) => _setScrubAt(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: _markers),
                liveGpsMapChild(),
                if (_areaBounds != null)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: [
                          _areaBounds!.northWest,
                          _areaBounds!.northEast,
                          _areaBounds!.southEast,
                          _areaBounds!.southWest,
                        ],
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.12),
                        borderColor: RideVizPalette.leanLeft,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (_selectMode)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // Keep bottom chrome + zoom controls tappable.
              bottom: 210,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onSelectPanStart,
                onPanUpdate: _onSelectPanUpdate,
                onPanEnd: _onSelectPanEnd,
                child: ValueListenableBuilder<(Offset?, Offset?)>(
                  valueListenable: _dragRect,
                  builder: (context, drag, _) {
                    return CustomPaint(
                      painter: _SelectionRectPainter(
                        start: drag.$1,
                        current: drag.$2,
                      ),
                    );
                  },
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  _TopBar(
                    title: l10n.fullscreenMap,
                    selecting: _selectMode,
                    onBack: _popWithScrub,
                    onToggleSelect: () {
                      _dragRect.value = (null, null);
                      setState(() {
                        _selectMode = !_selectMode;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                      child: MapLayerToggles(
                        options: _layers,
                        onChanged: (v) => setState(() {
                          _layers = v;
                          _rebuildTrackLayers();
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ZoomControls(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                      onMyLocation: () => recenterToLiveGpsOrNotify(_map),
                      onFit: _fitRide,
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.navigation,
                            size: 16,
                            color: AppTheme.lineHot,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${speed == null ? "--" : "${speed.toStringAsFixed(0)} ${l10n.kmh}"}'
                              '  ·  ${lean.abs().toStringAsFixed(0)}° $leanSide'
                              '  ·  ${_scrubIndex + 1}/${points.length}',
                              style: GoogleFonts.rajdhani(
                                color: AppTheme.mist,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_layers.showLegend)
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xCC1A1C1E),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: _layers.showRoadKindContrast
                            ? Text(
                                '${l10n.recta} · ${l10n.curva}',
                                style: GoogleFonts.rajdhani(
                                  color: AppTheme.steel,
                                  fontSize: 12,
                                ),
                              )
                            : const SpeedColorLegend(),
                      ),
                    ),
                  if (_layers.showLegend) const SizedBox(height: 10),
                  _BottomPanel(
                    selectMode: _selectMode,
                    hasSelection: hasFocus,
                    selection: _selection,
                    onUseVisible: _useVisibleArea,
                    onClear: _clearSelection,
                    onLoadMetrics: hasFocus ? _loadMetrics : null,
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  List<Polyline> _buildPolylines(
    List<TrackPoint> points, {
    int? focusLo,
    int? focusHi,
  }) {
    final kindByIndex = kindByIndexFromStretches(
      length: points.length,
      stretches: widget.roadStretches,
    );
    final hasFocus = focusLo != null && focusHi != null;
    if (!hasFocus) {
      final out = <Polyline>[];
      var cursor = 0;
      for (final segment in splitByGpsGaps(points)) {
        if (segment.length >= 2) {
          out.addAll(
            buildMergedStyledPolylines(
              segment: segment,
              indexOffset: cursor,
              kindByIndex: kindByIndex,
              showRoadKindContrast: _layers.showRoadKindContrast,
              showSpeedColors: _layers.showSpeedColors,
            ),
          );
        }
        cursor += segment.length;
      }
      return out;
    }
    final out = <Polyline>[];
    if (focusLo > 0) {
      out.addAll(_plainSegments(points.sublist(0, focusLo + 1), dimmed: true));
    }
    out.addAll(
      buildMergedStyledPolylines(
        segment: points.sublist(focusLo, focusHi + 1),
        indexOffset: focusLo,
        kindByIndex: kindByIndex,
        showRoadKindContrast: _layers.showRoadKindContrast,
        showSpeedColors: _layers.showSpeedColors,
      ),
    );
    if (focusHi < points.length - 1) {
      out.addAll(
        _plainSegments(points.sublist(focusHi, points.length), dimmed: true),
      );
    }
    return out;
  }

  List<Marker> _buildMarkers(
    List<TrackPoint> points, {
    int? focusLo,
    int? focusHi,
  }) {
    final markers = <Marker>[];
    final hasFocus = focusLo != null && focusHi != null;

    if (_layers.showBrakes) {
      for (final brake in widget.brakeEvents) {
        final mid = ((brake.startIndex + brake.endIndex) / 2).round();
        if (mid < 0 || mid >= points.length) continue;
        if (hasFocus && (mid < focusLo || mid > focusHi)) continue;
        final p = points[mid];
        markers.add(
          Marker(
            point: LatLng(p.latitude, p.longitude),
            width: 22,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                color: RideVizPalette.brakeColor(brake.hardness),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.asphalt, width: 2),
              ),
              child: const Icon(Icons.south, size: 12, color: AppTheme.asphalt),
            ),
          ),
        );
      }
    }

    if (_layers.showStartEnd) {
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

    final scrub = _scrubIndex;
    if (_layers.showPlayhead &&
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
            ),
            child:
                const Icon(Icons.navigation, size: 14, color: AppTheme.asphalt),
          ),
        ),
      );
    }
    return markers;
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.selecting,
    required this.onBack,
    required this.onToggleSelect,
  });

  final String title;
  final bool selecting;
  final VoidCallback onBack;
  final VoidCallback onToggleSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Material(
          color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.close),
            tooltip: l10n.back,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              selecting ? l10n.selectAreaHint : title,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: selecting
              ? RideVizPalette.leanLeft.withValues(alpha: 0.25)
              : AppTheme.asphaltElevated.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          child: IconButton(
            onPressed: onToggleSelect,
            icon: Icon(
              selecting ? Icons.crop_free : Icons.crop_square_outlined,
              color: selecting ? RideVizPalette.leanLeft : AppTheme.mist,
            ),
            tooltip: l10n.selectArea,
          ),
        ),
      ],
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        MapControlChip(
          icon: Icons.add,
          onPressed: onZoomIn,
          tooltip: l10n.zoomIn,
        ),
        const SizedBox(height: 8),
        MapControlChip(
          icon: Icons.remove,
          onPressed: onZoomOut,
          tooltip: l10n.zoomOut,
        ),
        const SizedBox(height: 8),
        MapMyLocationChip(onPressed: onMyLocation),
        const SizedBox(height: 8),
        MapControlChip(
          icon: Icons.fit_screen,
          onPressed: onFit,
          tooltip: l10n.fitRide,
        ),
      ],
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.selectMode,
    required this.hasSelection,
    required this.selection,
    required this.onUseVisible,
    required this.onClear,
    required this.onLoadMetrics,
  });

  final bool selectMode;
  final bool hasSelection;
  final ({int start, int end, int insideCount})? selection;
  final VoidCallback onUseVisible;
  final VoidCallback onClear;
  final VoidCallback? onLoadMetrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasSelection
              ? RideVizPalette.leanLeft.withValues(alpha: 0.45)
              : AppTheme.mist.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectMode
                ? l10n.selectAreaBody
                : (hasSelection
                    ? l10n.areaReady(
                        selection!.end - selection!.start + 1,
                      )
                    : l10n.fullscreenMapHelp),
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onUseVisible,
                  child: Text(l10n.useVisibleArea),
                ),
              ),
              if (hasSelection) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onClear,
                  child: Text(l10n.clearArea),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onLoadMetrics,
            child: Text(l10n.loadAreaMetrics),
          ),
        ],
      ),
    );
  }
}

class _SelectionRectPainter extends CustomPainter {
  _SelectionRectPainter({this.start, this.current});

  final Offset? start;
  final Offset? current;

  @override
  void paint(Canvas canvas, Size size) {
    final a = start;
    final b = current;
    if (a == null || b == null) return;
    final rect = Rect.fromPoints(a, b);
    final fill = Paint()
      ..color = RideVizPalette.leanLeft.withValues(alpha: 0.18);
    final stroke = Paint()
      ..color = RideVizPalette.leanLeft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _SelectionRectPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.current != current;
  }
}
