import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_build_info.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/app_localizations.dart';
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
  final LocationService _location = LocationService();
  final List<LatLng> _points = [];
  final List<DateTime> _timestamps = [];

  StreamSubscription<Position>? _recordSub;
  bool _recording = false;
  bool _follow = true;
  double? _lastAccuracyM;
  int _rejectedAccuracy = 0;
  String? _lastError;

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

  Future<void> _startRecording() async {
    if (_recording) return;
    final ok = await LocationPermissionGate.requestForRecording(context);
    if (!ok || !mounted) return;

    // One high-rate stream only — don't fight the live blue-dot stream.
    stopLiveGps();
    await _recordSub?.cancel();

    setState(() {
      _recording = true;
      _follow = true;
      _rejectedAccuracy = 0;
      _lastError = null;
    });

    // Seed immediately so the rider sees a first point without waiting.
    try {
      final seed = await _location.currentPosition();
      if (mounted && seed != null && _recording) {
        _acceptFix(seed, force: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = '$e');
      }
    }

    // Same FGS + wake-lock path as ride recording (S25 / Android 14+).
    _recordSub = _location
        .watchPositions(
          notificationTitle: 'RiderLab lab',
          notificationText: 'Grabando perímetro GPS…',
        )
        .listen(
          (pos) {
            if (!mounted || !_recording) return;
            _acceptFix(pos);
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _lastError = '$e';
              _recording = false;
            });
            showAppSnackError(context, '$e');
          },
        );
  }

  void _acceptFix(Position pos, {bool force = false}) {
    final acc = pos.accuracy;
    if (acc.isFinite) _lastAccuracyM = acc;
    // Soft filter: keep continuity; only drop garbage unless seeding.
    if (!force && acc.isFinite && acc > LocationService.maxAcceptAccuracyMeters) {
      _rejectedAccuracy++;
      if (mounted) setState(() {});
      return;
    }
    final ll = LatLng(pos.latitude, pos.longitude);
    final ts = pos.timestamp;
    setState(() {
      _points.add(ll);
      _timestamps.add(ts);
      liveGpsListenable.value = ll;
    });
    if (_follow) {
      try {
        final zoom = _map.camera.zoom < 15 ? 17.0 : _map.camera.zoom;
        _map.move(ll, zoom);
      } catch (_) {}
    }
  }

  Future<void> _stopRecording() async {
    await _recordSub?.cancel();
    _recordSub = null;
    if (!mounted) return;
    setState(() => _recording = false);
    // Restore lightweight blue-dot for browsing the result.
    await startLiveGps(map: _map, centerOnce: false);
  }

  void _clear() {
    setState(() {
      _points.clear();
      _timestamps.clear();
      _rejectedAccuracy = 0;
      _lastError = null;
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

  String _statusLine(AppLocalizations l10n) {
    final hz = _avgHz();
    final meters = _pathMeters();
    final dist = meters < 1000
        ? '${meters.toStringAsFixed(0)} m'
        : '${(meters / 1000).toStringAsFixed(2)} km';
    final acc = _lastAccuracyM == null
        ? '—'
        : '±${_lastAccuracyM!.toStringAsFixed(0)} m';
    if (_recording) {
      return '${l10n.gpsTrackPointsLabRecordingStats(
        _points.length,
        hz == null ? '—' : hz.toStringAsFixed(1),
        dist,
      )} · $acc'
          '${_rejectedAccuracy > 0 ? ' · rechazados $_rejectedAccuracy' : ''}';
    }
    if (_points.isEmpty) {
      final err = _lastError;
      if (err != null) return err;
      return l10n.gpsTrackPointsLabIdleHint;
    }
    return l10n.gpsTrackPointsLabStoppedStats(
      _points.length,
      hz == null ? '—' : hz.toStringAsFixed(1),
      dist,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buildAsync = ref.watch(appBuildInfoProvider);
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
                        _statusLine(l10n),
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
                    icon: Icon(
                      _recording ? Icons.stop : Icons.radio_button_checked,
                    ),
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
