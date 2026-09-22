import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';

/// Full-screen map showing every stored GPS fix for one ride.
class GpsTrackPointsMapScreen extends ConsumerStatefulWidget {
  const GpsTrackPointsMapScreen({
    super.key,
    required this.rideId,
    required this.rideTitle,
  });

  final String rideId;
  final String rideTitle;

  @override
  ConsumerState<GpsTrackPointsMapScreen> createState() =>
      _GpsTrackPointsMapScreenState();
}

class _GpsTrackPointsMapScreenState extends ConsumerState<GpsTrackPointsMapScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  bool _showPolyline = true;

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  double? _avgHz(List<TrackPoint> points) {
    if (points.length < 2) return null;
    final dt = points.last.timestamp
        .difference(points.first.timestamp)
        .inMilliseconds;
    if (dt <= 0) return null;
    return points.length / (dt / 1000);
  }

  List<CircleMarker> _circles(List<TrackPoint> points) {
    return [
      for (final p in points)
        CircleMarker(
          point: LatLng(p.latitude, p.longitude),
          radius: 5,
          color: AppTheme.line.withValues(alpha: 0.95),
          borderColor: AppTheme.mist.withValues(alpha: 0.55),
          borderStrokeWidth: 0.8,
        ),
    ];
  }

  List<Polyline> _polylines(List<TrackPoint> points) {
    if (!_showPolyline || points.length < 2) return const [];
    return [
      Polyline(
        points: [for (final p in points) LatLng(p.latitude, p.longitude)],
        color: AppTheme.steel.withValues(alpha: 0.45),
        strokeWidth: 3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pointsAsync = ref.watch(ridePointsProvider(widget.rideId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gpsTrackPointsLabMapTitle),
        actions: [
          IconButton(
            tooltip: l10n.gpsTrackPointsLabToggleLine,
            onPressed: () => setState(() => _showPolyline = !_showPolyline),
            icon: Icon(
              _showPolyline ? Icons.timeline : Icons.timeline_outlined,
              color: _showPolyline ? AppTheme.line : AppTheme.steel,
            ),
          ),
        ],
      ),
      body: pointsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppTheme.steel)),
        ),
        data: (points) {
          if (points.length < 2) {
            return Center(
              child: Text(
                l10n.noGpsPoints,
                style: const TextStyle(color: AppTheme.steel),
              ),
            );
          }
          final bounds = LatLngBounds.fromPoints([
            for (final p in points) LatLng(p.latitude, p.longitude),
          ]);
          final center = LatLng(
            points[points.length ~/ 2].latitude,
            points[points.length ~/ 2].longitude,
          );
          final hz = _avgHz(points);
          final duration = points.last.timestamp
              .difference(points.first.timestamp);

          return Stack(
            children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 15,
                    initialCameraFit: CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(48),
                      maxZoom: 17,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rawthrottle.riderlab',
                    ),
                    PolylineLayer(polylines: _polylines(points)),
                    CircleLayer(circles: _circles(points)),
                    liveGpsMapChild(),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.rideTitle,
                                style: GoogleFonts.rajdhani(
                                  color: AppTheme.mist,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.gpsTrackPointsLabStats(
                                  points.length,
                                  hz == null ? '—' : hz.toStringAsFixed(1),
                                  _formatDuration(duration),
                                ),
                                style: GoogleFonts.rajdhani(
                                  color: AppTheme.steel,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FloatingActionButton.small(
                          heroTag: 'gps-lab-fit',
                          onPressed: () {
                            _map.fitCamera(
                              CameraFit.bounds(
                                bounds: bounds,
                                padding: const EdgeInsets.all(48),
                                maxZoom: 17,
                              ),
                            );
                          },
                          child: const Icon(Icons.fit_screen),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s}s';
  }
}
