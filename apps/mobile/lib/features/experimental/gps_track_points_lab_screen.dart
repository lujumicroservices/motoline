import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_build_info.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';
import '../maps/map_control_chip.dart';
import '../ride_active/location_permission_gate.dart';
import '../../widgets/app_snack.dart';

/// Experimental lab: live map at current GPS + record a perimeter of fixes.
class GpsTrackPointsLabScreen extends ConsumerStatefulWidget {
  const GpsTrackPointsLabScreen({super.key});

  @override
  ConsumerState<GpsTrackPointsLabScreen> createState() =>
      _GpsTrackPointsLabScreenState();
}

class _GpsTrackPointsLabScreenState
    extends ConsumerState<GpsTrackPointsLabScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  final List<LatLng> _points = [];
  final List<DateTime> _timestamps = [];

  StreamSubscription<Position>? _recordSub;
  bool _recording = false;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    final ok = await LocationPermissionGate.requestForRecording(context);
    if (!ok || !mounted) return;
    await startLiveGps(map: _map, centerOnce: true);
  }

  @override
  void dispose() {
    unawaited(_recordSub?.cancel());
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  LocationSettings _recordSettings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 100),
        forceLocationManager: false,
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    final ok = await LocationPermissionGate.requestForRecording(context);
    if (!ok || !mounted) return;

    await _recordSub?.cancel();
    setState(() {
      _recording = true;
      _follow = true;
    });

    _recordSub = Geolocator.getPositionStream(
      locationSettings: _recordSettings(),
    ).listen(
      (pos) {
        if (!mounted || !_recording) return;
        if (pos.accuracy > 40) return;
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _points.add(ll);
          _timestamps.add(pos.timestamp);
        });
        if (_follow) {
          try {
            final zoom = _map.camera.zoom < 15 ? 17.0 : _map.camera.zoom;
            _map.move(ll, zoom);
          } catch (_) {}
        }
      },
      onError: (Object e) {
        if (!mounted) return;
        showAppSnackError(context, '$e');
        setState(() => _recording = false);
      },
    );
  }

  Future<void> _stopRecording() async {
    await _recordSub?.cancel();
    _recordSub = null;
    if (!mounted) return;
    setState(() => _recording = false);
  }

  void _clear() {
    setState(() {
      _points.clear();
      _timestamps.clear();
    });
  }

  double? _avgHz() {
    if (_timestamps.length < 2) return null;
    final dt = _timestamps.last.difference(_timestamps.first).inMilliseconds;
    if (dt <= 0) return null;
    return _timestamps.length / (dt / 1000);
  }

  double _pathMeters() {
    if (_points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < _points.length; i++) {
      sum += haversineMeters(
        _points[i - 1].latitude,
        _points[i - 1].longitude,
        _points[i].latitude,
        _points[i].longitude,
      );
    }
    return sum;
  }

  List<CircleMarker> _circles() => [
        for (final p in _points)
          CircleMarker(
            point: p,
            radius: 5,
            color: AppTheme.line.withValues(alpha: 0.95),
            borderColor: AppTheme.mist.withValues(alpha: 0.55),
            borderStrokeWidth: 0.8,
          ),
      ];

  List<Polyline> _polylines() {
    if (_points.length < 2) return const [];
    return [
      Polyline(
        points: List<LatLng>.of(_points),
        color: AppTheme.lineHot.withValues(alpha: 0.7),
        strokeWidth: 3,
      ),
    ];
  }

  List<Polygon> _polygons() {
    if (_points.length < 3 || _recording) return const [];
    final closeEnough = haversineMeters(
          _points.first.latitude,
          _points.first.longitude,
          _points.last.latitude,
          _points.last.longitude,
        ) <=
        25;
    if (!closeEnough) return const [];
    return [
      Polygon(
        points: List<LatLng>.of(_points),
        color: AppTheme.line.withValues(alpha: 0.18),
        borderColor: AppTheme.line,
        borderStrokeWidth: 2,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buildAsync = ref.watch(appBuildInfoProvider);
    final hz = _avgHz();
    final meters = _pathMeters();
    final center = liveGps ?? const LatLng(20.67, -103.35);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(l10n.gpsTrackPointsLabTitle),
        actions: [
          if (_points.isNotEmpty)
            IconButton(
              tooltip: l10n.gpsTrackPointsLabClear,
              onPressed: _recording ? null : _clear,
              icon: const Icon(Icons.delete_outline),
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
                initialZoom: 17,
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && _follow) {
                    setState(() => _follow = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rawthrottle.riderlab',
                ),
                PolylineLayer(polylines: _polylines()),
                if (_polygons().isNotEmpty) PolygonLayer(polygons: _polygons()),
                if (_circles().isNotEmpty) CircleLayer(circles: _circles()),
                liveGpsMapChild(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (info) => Material(
                      color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          info.fullLine,
                          style: GoogleFonts.rajdhani(
                            color: AppTheme.mist,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Text(
                        _recording
                            ? l10n.gpsTrackPointsLabRecordingStats(
                                _points.length,
                                hz == null ? '—' : hz.toStringAsFixed(1),
                                meters < 1000
                                    ? '${meters.toStringAsFixed(0)} m'
                                    : '${(meters / 1000).toStringAsFixed(2)} km',
                              )
                            : _points.isEmpty
                                ? l10n.gpsTrackPointsLabIdleHint
                                : l10n.gpsTrackPointsLabStoppedStats(
                                    _points.length,
                                    hz == null
                                        ? '—'
                                        : hz.toStringAsFixed(1),
                                    meters < 1000
                                        ? '${meters.toStringAsFixed(0)} m'
                                        : '${(meters / 1000).toStringAsFixed(2)} km',
                                  ),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
                        MapControlChip(
                          icon: Icons.add,
                          tooltip: l10n.zoomIn,
                          onPressed: () {
                            final cam = _map.camera;
                            _map.move(
                              cam.center,
                              (cam.zoom + 1).clamp(3.0, 19.0),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        MapControlChip(
                          icon: Icons.remove,
                          tooltip: l10n.zoomOut,
                          onPressed: () {
                            final cam = _map.camera;
                            _map.move(
                              cam.center,
                              (cam.zoom - 1).clamp(3.0, 19.0),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        MapMyLocationChip(
                          onPressed: () {
                            setState(() => _follow = true);
                            recenterToLiveGpsOrNotify(_map);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          _recording ? AppTheme.signal : AppTheme.line,
                      foregroundColor: AppTheme.asphalt,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _recording ? _stopRecording : _startRecording,
                    icon: Icon(_recording ? Icons.stop : Icons.radio_button_checked),
                    label: Text(
                      _recording
                          ? l10n.gpsTrackPointsLabStopPerimeter
                          : l10n.gpsTrackPointsLabStartPerimeter,
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
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
