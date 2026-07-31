import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
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
    this.initialFocusStart,
    this.initialFocusEnd,
  });

  final List<TrackPoint> points;
  final int? scrubIndex;
  final List<BrakeEvent> brakeEvents;
  final int? initialFocusStart;
  final int? initialFocusEnd;

  @override
  State<FullscreenMapScreen> createState() => _FullscreenMapScreenState();
}

class _FullscreenMapScreenState extends State<FullscreenMapScreen> {
  final MapController _map = MapController();

  bool _selectMode = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  LatLngBounds? _areaBounds;
  ({int start, int end, int insideCount})? _selection;

  @override
  void initState() {
    super.initState();
    final lo = widget.initialFocusStart;
    final hi = widget.initialFocusEnd;
    if (lo != null && hi != null && hi > lo && hi < widget.points.length) {
      _selection = (start: lo, end: hi, insideCount: hi - lo + 1);
    }
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

  void _zoomBy(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
  }

  void _applyBounds(LatLngBounds bounds) {
    final hit = segmentIndicesInBounds(
      points: widget.points,
      isInside: (p) => bounds.contains(LatLng(p.latitude, p.longitude)),
    );
    setState(() {
      _areaBounds = bounds;
      _selection = hit;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _useVisibleArea() {
    _applyBounds(_map.camera.visibleBounds);
  }

  void _onSelectPanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _dragCurrent = details.localPosition;
    });
  }

  void _onSelectPanUpdate(DragUpdateDetails details) {
    setState(() => _dragCurrent = details.localPosition);
  }

  void _onSelectPanEnd(DragEndDetails details) {
    final a = _dragStart;
    final b = _dragCurrent;
    if (a == null || b == null) return;
    if ((a - b).distance < 24) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
      return;
    }
    final cam = _map.camera;
    final p1 = cam.screenOffsetToLatLng(a);
    final p2 = cam.screenOffsetToLatLng(b);
    _applyBounds(LatLngBounds(p1, p2));
  }

  void _clearSelection() {
    setState(() {
      _areaBounds = null;
      _selection = null;
      _dragStart = null;
      _dragCurrent = null;
    });
  }

  void _loadMetrics() {
    final sel = _selection;
    if (sel == null || sel.end <= sel.start) return;
    Navigator.of(context).pop(
      FullscreenMapSelection(startIndex: sel.start, endIndex: sel.end),
    );
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

    final bounds = LatLngBounds.fromPoints([
      for (final p in points) LatLng(p.latitude, p.longitude),
    ]);
    final center = LatLng(
      points[points.length ~/ 2].latitude,
      points[points.length ~/ 2].longitude,
    );

    final focusLo = _selection?.start;
    final focusHi = _selection?.end;
    final hasFocus = focusLo != null && focusHi != null;

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      body: Stack(
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
                      ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                      : InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                PolylineLayer(
                  polylines: _buildPolylines(
                    points,
                    focusLo: focusLo,
                    focusHi: focusHi,
                  ),
                ),
                MarkerLayer(
                  markers: _buildMarkers(
                    points,
                    focusLo: focusLo,
                    focusHi: focusHi,
                  ),
                ),
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
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onSelectPanStart,
                onPanUpdate: _onSelectPanUpdate,
                onPanEnd: _onSelectPanEnd,
                child: CustomPaint(
                  painter: _SelectionRectPainter(
                    start: _dragStart,
                    current: _dragCurrent,
                  ),
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
                    onBack: () => Navigator.of(context).pop(),
                    onToggleSelect: () {
                      setState(() {
                        _selectMode = !_selectMode;
                        _dragStart = null;
                        _dragCurrent = null;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ZoomControls(
                      onZoomIn: () => _zoomBy(1),
                      onZoomOut: () => _zoomBy(-1),
                      onFit: _fitRide,
                    ),
                  ),
                  const Spacer(),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xCC1A1C1E),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: SpeedColorLegend(),
                    ),
                  ),
                  const SizedBox(height: 10),
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
    );
  }

  List<Polyline> _buildPolylines(
    List<TrackPoint> points, {
    int? focusLo,
    int? focusHi,
  }) {
    final hasFocus = focusLo != null && focusHi != null;
    if (!hasFocus) {
      final out = <Polyline>[];
      for (final segment in splitByGpsGaps(points)) {
        if (segment.length < 2) continue;
        out.addAll(_coloredSegments(segment));
      }
      return out;
    }
    final out = <Polyline>[];
    if (focusLo > 0) {
      out.addAll(_plainSegments(points.sublist(0, focusLo + 1), dimmed: true));
    }
    out.addAll(_coloredSegments(points.sublist(focusLo, focusHi + 1)));
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

    final scrub = widget.scrubIndex;
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
            ),
            child:
                const Icon(Icons.navigation, size: 14, color: AppTheme.asphalt),
          ),
        ),
      );
    }
    return markers;
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
              style: GoogleFonts.spaceGrotesk(
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
    required this.onFit,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget chip({
      required IconData icon,
      required VoidCallback onPressed,
      required String tooltip,
    }) {
      return Material(
        color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          tooltip: tooltip,
        ),
      );
    }

    return Column(
      children: [
        chip(icon: Icons.add, onPressed: onZoomIn, tooltip: l10n.zoomIn),
        const SizedBox(height: 8),
        chip(icon: Icons.remove, onPressed: onZoomOut, tooltip: l10n.zoomOut),
        const SizedBox(height: 8),
        chip(
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
            style: GoogleFonts.outfit(
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
