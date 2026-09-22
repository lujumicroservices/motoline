import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import 'circuit_8h_models.dart';
import 'circuit_8h_store.dart';

/// View one saved pass: GPS track + circuit markers.
class Circuit8hPassViewScreen extends StatefulWidget {
  const Circuit8hPassViewScreen({
    super.key,
    required this.session,
    required this.passIndex,
  });

  final Circuit8hSession session;
  final int passIndex;

  @override
  State<Circuit8hPassViewScreen> createState() =>
      _Circuit8hPassViewScreenState();
}

class _Circuit8hPassViewScreenState extends State<Circuit8hPassViewScreen> {
  final MapController _map = MapController();
  Circuit8hProject _project = const Circuit8hProject();
  bool _showPoints = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final project = await loadCircuit8hProject();
    if (!mounted) return;
    setState(() => _project = project);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  List<LatLng> get _latLngs => [
        for (final p in widget.session.points) LatLng(p.lat, p.lng),
      ];

  Color get _accent => widget.session.routeType == Circuit8hRouteType.a
      ? AppTheme.lineHot
      : AppTheme.line;

  void _fit() {
    final pts = <LatLng>[
      ..._latLngs,
      if (_project.start != null)
        LatLng(_project.start!.lat, _project.start!.lng),
      if (_project.finish != null)
        LatLng(_project.finish!.lat, _project.finish!.lng),
      for (final c in _project.checkpoints) LatLng(c.lat, c.lng),
    ];
    if (pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        _map.move(pts.first, 17);
        return;
      }
      final bounds = LatLngBounds.fromPoints(pts);
      _map.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    } catch (_) {}
  }

  double _pathMeters() {
    final pts = widget.session.points;
    if (pts.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < pts.length; i++) {
      sum += haversineMeters(
        pts[i - 1].lat,
        pts[i - 1].lng,
        pts[i].lat,
        pts[i].lng,
      );
    }
    return sum;
  }

  List<Marker> _markers() {
    final l10n = context.l10n;
    final out = <Marker>[];
    void pin(Circuit8hMarker m, Color color, IconData icon, String tip) {
      out.add(
        Marker(
          point: LatLng(m.lat, m.lng),
          width: 40,
          height: 40,
          child: Tooltip(
            message: tip,
            child: Icon(icon, color: color, size: 32),
          ),
        ),
      );
    }

    if (_project.start != null) {
      pin(
        _project.start!,
        AppTheme.line,
        Icons.flag,
        l10n.circuit8hMarkStart,
      );
    }
    for (final cp in _project.checkpoints) {
      pin(
        cp,
        AppTheme.lineHot,
        Icons.location_on,
        cp.label ?? l10n.circuit8hMarkCheckpoint,
      );
    }
    if (_project.finish != null) {
      pin(
        _project.finish!,
        AppTheme.signal,
        Icons.sports_score,
        l10n.circuit8hMarkFinish,
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pts = _latLngs;
    final meters = _pathMeters();
    final dist = meters < 1000
        ? '${meters.toStringAsFixed(0)} m'
        : '${(meters / 1000).toStringAsFixed(2)} km';
    final dur = widget.session.duration;
    final durLabel = dur.inMinutes <= 0
        ? '${dur.inSeconds}s'
        : '${dur.inMinutes}m ${(dur.inSeconds % 60).toString().padLeft(2, '0')}s';
    final center = pts.isNotEmpty ? pts.first : const LatLng(20.67, -103.35);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.circuit8hPassViewTitle(
            widget.session.routeType.label,
            widget.passIndex,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.circuit8hTogglePoints,
            onPressed: () => setState(() => _showPoints = !_showPoints),
            icon: Icon(
              _showPoints ? Icons.grain : Icons.timeline,
            ),
          ),
          IconButton(
            tooltip: l10n.circuit8hFitMarkers,
            onPressed: _fit,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rawthrottle.riderlab',
                ),
                if (pts.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: pts,
                        color: _accent.withValues(alpha: 0.9),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (_showPoints && pts.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final p in pts)
                        CircleMarker(
                          point: p,
                          radius: 4,
                          color: _accent.withValues(alpha: 0.95),
                          borderColor: AppTheme.mist.withValues(alpha: 0.45),
                          borderStrokeWidth: 0.6,
                        ),
                    ],
                  ),
                if (_markers().isNotEmpty) MarkerLayer(markers: _markers()),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Material(
                  color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Text(
                      l10n.circuit8hPassViewStats(
                        widget.session.pointCount,
                        dist,
                        durLabel,
                      ),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.mist,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
