import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/track_point.dart';
import '../../core/services/loop_session_controller.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

enum _MarkStep { placeA, placeB, done }

/// Fullscreen interactive map to mark loop start (A) and end (B) by tapping.
class LoopMarkMapScreen extends StatefulWidget {
  const LoopMarkMapScreen({
    super.key,
    required this.points,
    this.initialInit,
    this.initialEnd,
  });

  final List<TrackPoint> points;
  final LatLng? initialInit;
  final LatLng? initialEnd;

  @override
  State<LoopMarkMapScreen> createState() => _LoopMarkMapScreenState();
}

class _LoopMarkMapScreenState extends State<LoopMarkMapScreen> {
  final MapController _map = MapController();

  LatLng? _pointA;
  LatLng? _pointB;
  late _MarkStep _step;

  @override
  void initState() {
    super.initState();
    _pointA = widget.initialInit;
    _pointB = widget.initialEnd;
    if (_pointA == null) {
      _step = _MarkStep.placeA;
    } else if (_pointB == null) {
      _step = _MarkStep.placeB;
    } else {
      _step = _MarkStep.done;
    }
  }

  void _onTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      if (_step == _MarkStep.placeA || (_step == _MarkStep.done && _pointA == null)) {
        _pointA = latlng;
        _step = _MarkStep.placeB;
      } else if (_step == _MarkStep.placeB || _step == _MarkStep.done) {
        _pointB = latlng;
        _step = _MarkStep.done;
      }
    });
  }

  void _fitRide() {
    if (widget.points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([
      for (final p in widget.points) LatLng(p.latitude, p.longitude),
    ]);
    _map.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
        maxZoom: 17,
      ),
    );
  }

  void _zoomBy(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
  }

  Future<void> _confirm(BuildContext context) async {
    final a = _pointA;
    final b = _pointB;
    if (a == null || b == null) return;
    // Result consumed by caller via Navigator.pop — controller applied there
    // so this screen stays presentation-only when embedded without Riverpod.
    if (!context.mounted) return;
    Navigator.of(context).pop(
      LoopMarkResult(init: a, end: b),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = widget.points;

    LatLng center;
    LatLngBounds? bounds;
    if (points.isNotEmpty) {
      bounds = LatLngBounds.fromPoints([
        for (final p in points) LatLng(p.latitude, p.longitude),
      ]);
      center = LatLng(
        points[points.length ~/ 2].latitude,
        points[points.length ~/ 2].longitude,
      );
    } else {
      center = _pointA ?? const LatLng(19.43, -99.13);
    }

    final line = <LatLng>[
      for (final p in points) LatLng(p.latitude, p.longitude),
    ];

    final hint = switch (_step) {
      _MarkStep.placeA => l10n.loopTapPointA,
      _MarkStep.placeB => l10n.loopTapPointB,
      _MarkStep.done => l10n.loopPointsReady,
    };

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
                initialCameraFit: bounds == null
                    ? null
                    : CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.fromLTRB(40, 120, 40, 220),
                        maxZoom: 17,
                      ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                if (line.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: line,
                        strokeWidth: 5,
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                if (_pointA != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _pointA!,
                        radius: kLoopGeofenceRadiusMeters,
                        useRadiusInMeter: true,
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.15),
                        borderColor: RideVizPalette.leanLeft,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_pointA != null)
                      Marker(
                        point: _pointA!,
                        width: 40,
                        height: 40,
                        child: _AbMarker(label: 'A', color: RideVizPalette.leanLeft),
                      ),
                    if (_pointB != null)
                      Marker(
                        point: _pointB!,
                        width: 40,
                        height: 40,
                        child: _AbMarker(label: 'B', color: RideVizPalette.leanRight),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: l10n.back,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.asphaltElevated
                                .withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            hint,
                            style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
                        _ZoomChip(
                          icon: Icons.add,
                          onPressed: () => _zoomBy(1),
                          tooltip: l10n.zoomIn,
                        ),
                        const SizedBox(height: 8),
                        _ZoomChip(
                          icon: Icons.remove,
                          onPressed: () => _zoomBy(-1),
                          tooltip: l10n.zoomOut,
                        ),
                        const SizedBox(height: 8),
                        _ZoomChip(
                          icon: Icons.fit_screen,
                          onPressed: _fitRide,
                          tooltip: l10n.fitRide,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: AppTheme.asphaltElevated.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.loopMarkMapHelp,
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
                                onPressed: () => setState(() {
                                  _pointA = null;
                                  _pointB = null;
                                  _step = _MarkStep.placeA;
                                }),
                                child: Text(l10n.clearArea),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pointA == null
                                    ? null
                                    : () => setState(() {
                                          _step = _MarkStep.placeA;
                                        }),
                                child: Text(l10n.loopRemapA),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: (_pointA != null && _pointB != null)
                              ? () => _confirm(context)
                              : null,
                          child: Text(l10n.loopConfirmAb),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoopMarkResult {
  const LoopMarkResult({required this.init, required this.end});

  final LatLng init;
  final LatLng end;
}

class _AbMarker extends StatelessWidget {
  const _AbMarker({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.mist, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          fontWeight: FontWeight.w800,
          color: AppTheme.asphalt,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _ZoomChip extends StatelessWidget {
  const _ZoomChip({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
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
}
