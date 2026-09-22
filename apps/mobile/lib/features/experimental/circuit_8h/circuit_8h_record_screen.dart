import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_snack.dart';
import '../../maps/live_gps_map_mixin.dart';
import '../../maps/map_control_chip.dart';
import '../../ride_active/location_permission_gate.dart';
import 'circuit_8h_models.dart';
import 'circuit_8h_precision.dart';
import 'circuit_8h_store.dart';

/// Record one GPS pass for route A or B, with start / checkpoints / finish
/// markers on the same screen.
class Circuit8hRecordScreen extends ConsumerStatefulWidget {
  const Circuit8hRecordScreen({
    super.key,
    required this.routeType,
    required this.passNumber,
  });

  final Circuit8hRouteType routeType;
  final int passNumber;

  @override
  ConsumerState<Circuit8hRecordScreen> createState() =>
      _Circuit8hRecordScreenState();
}

class _Circuit8hRecordScreenState extends ConsumerState<Circuit8hRecordScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  final LocationService _location = LocationService();
  final List<Circuit8hPoint> _points = [];

  Circuit8hProject _project = const Circuit8hProject();
  StreamSubscription<Position>? _recordSub;
  bool _recording = false;
  bool _warming = false;
  bool _sampling = false;
  bool _skipLock = false;
  bool _looseGate = false;
  bool _follow = true;
  bool _saving = false;
  double? _lastAccuracyM;
  int _rejectedAccuracy = 0;
  String? _lastError;
  int? _startedAtMs;
  Circuit8hTrackEdge? _edge;
  int _captureGen = 0;
  Position? _held;
  final List<Circuit8hSurveySample> _tight = [];

  Color get _accent => widget.routeType == Circuit8hRouteType.a
      ? AppTheme.lineHot
      : AppTheme.line;

  int get _nextCp => _project.checkpointCount + 1;

  /// ±4 m unless the pilot chose to record before that lock.
  double get _acceptMeters => _looseGate
      ? LocationService.maxAcceptAccuracyMeters
      : circuit8hMaxAcceptAccuracyMeters;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (!mounted) return;
    final project = await loadCircuit8hProject();
    if (!mounted) return;
    setState(() => _project = project);
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

  Future<void> _persist(Circuit8hProject next) async {
    setState(() => _project = next);
    try {
      await saveCircuit8hProject(next);
    } catch (e) {
      if (mounted) showAppSnackError(context, '$e');
    }
  }

  Future<Circuit8hSurveySample?> _readSurveySample() async {
    final pos = await _location.currentPosition();
    if (pos == null || !pos.accuracy.isFinite) return null;
    return Circuit8hSurveySample(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      tsMs: pos.timestamp.millisecondsSinceEpoch,
    );
  }

  Future<void> _placeMarker(Circuit8hMarkerKind kind) async {
    if (_sampling) return;
    setState(() => _sampling = true);
    final Circuit8hMarkerFix? fix;
    try {
      if (_recording && _tight.isNotEmpty) {
        fix = medianMarkerFix(
          _tight,
          maxAccuracyMeters: _acceptMeters,
        );
      } else {
        final samples = await collectSurveySamples(
          read: _readSurveySample,
          cancelled: () => !mounted,
        );
        fix = medianMarkerFix(samples);
      }
    } finally {
      if (mounted) setState(() => _sampling = false);
    }
    if (!mounted) return;
    if (fix == null) {
      showAppSnackError(
        context,
        context.l10n.circuit8hHoldStill(
          circuit8hMarkerMinSamples,
          circuit8hMaxAcceptAccuracyMeters.round(),
        ),
      );
      return;
    }
    final marker = Circuit8hMarker(
      id: 'mk_${kind.id}_${fix.tsMs}',
      kind: kind,
      lat: fix.lat,
      lng: fix.lng,
      tsMs: fix.tsMs,
      accuracyM: fix.accuracyM,
      label: kind == Circuit8hMarkerKind.checkpoint ? 'CP$_nextCp' : null,
    );
    final next = switch (kind) {
      Circuit8hMarkerKind.start => _project.withStart(marker),
      Circuit8hMarkerKind.finish => _project.withFinish(marker),
      Circuit8hMarkerKind.checkpoint => _project.withCheckpoint(marker),
    };
    await _persist(next);
  }

  Future<void> _clearStart() async {
    await _persist(_project.copyWith(clearStart: true));
  }

  Future<void> _clearFinish() async {
    await _persist(_project.copyWith(clearFinish: true));
  }

  Future<void> _deleteCheckpoint(String id) async {
    var next = _project.withoutCheckpoint(id);
    // Renumber remaining CPs so labels stay CP1..N.
    final renumbered = <Circuit8hMarker>[];
    for (var i = 0; i < next.checkpoints.length; i++) {
      final c = next.checkpoints[i];
      renumbered.add(
        Circuit8hMarker(
          id: c.id,
          kind: c.kind,
          lat: c.lat,
          lng: c.lng,
          tsMs: c.tsMs,
          accuracyM: c.accuracyM,
          label: 'CP${i + 1}',
        ),
      );
    }
    next = next.copyWith(checkpoints: renumbered);
    await _persist(next);
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    if (_edge == null) {
      showAppSnackError(context, context.l10n.circuit8hEdgeRequired);
      return;
    }
    final ok = await LocationPermissionGate.requestForRecording(context);
    if (!ok || !mounted) return;

    stopLiveGps();
    await _recordSub?.cancel();
    final gen = ++_captureGen;

    setState(() {
      _recording = true;
      _warming = true;
      _skipLock = false;
      _looseGate = false;
      _follow = true;
      _rejectedAccuracy = 0;
      _lastError = null;
      _points.clear();
      _held = null;
      _tight.clear();
      _startedAtMs = DateTime.now().millisecondsSinceEpoch;
    });

    try {
      var locked = false;
      while (!locked && !_skipLock && mounted && gen == _captureGen) {
        await for (final status in _location.warmUpGnss(
          timeout: const Duration(seconds: 8),
          targetAccuracyMeters: circuit8hMaxAcceptAccuracyMeters,
        )) {
          if (!mounted || gen != _captureGen) return;
          setState(() => _lastAccuracyM = status.accuracyMeters);
          if (status.phase == GpsWarmupPhase.ready) {
            locked = true;
            break;
          }
          if (_skipLock || status.phase == GpsWarmupPhase.timeout) break;
        }
      }
    } catch (e) {
      if (mounted && gen == _captureGen) setState(() => _lastError = '$e');
    }
    if (!mounted || gen != _captureGen) return;
    setState(() {
      _warming = false;
      _looseGate = _skipLock;
    });

    try {
      final seed = await _location.currentPosition();
      if (mounted && seed != null && gen == _captureGen) {
        _acceptFix(seed);
      }
    } catch (e) {
      if (mounted && gen == _captureGen) setState(() => _lastError = '$e');
    }
    if (!mounted || gen != _captureGen) return;

    final label = widget.routeType.label;
    _recordSub = _location
        .watchPositions(
          notificationTitle: 'RiderLab · Circuito 8h',
          notificationText:
              'Grabando recorrido $label pasada ${widget.passNumber}…',
        )
        .listen(
          (pos) {
            if (!mounted || !_recording || gen != _captureGen) return;
            _acceptFix(pos);
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() {
              _lastError = '$e';
              _recording = false;
              _warming = false;
            });
            showAppSnackError(context, '$e');
          },
        );
  }

  void _rememberTight(Position pos) {
    if (!pos.accuracy.isFinite) return;
    final ts = pos.timestamp.millisecondsSinceEpoch;
    _tight.add(
      Circuit8hSurveySample(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        tsMs: ts,
      ),
    );
    final cutoff = ts - 4000;
    _tight.removeWhere((s) => s.tsMs < cutoff);
  }

  void _storeFix(Position pos) {
    final acc = pos.accuracy;
    final ll = LatLng(pos.latitude, pos.longitude);
    final point = Circuit8hPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      tsMs: pos.timestamp.millisecondsSinceEpoch,
      accuracyM: acc.isFinite ? acc : null,
    );
    setState(() {
      _points.add(point);
      liveGpsListenable.value = ll;
    });
    if (_follow) {
      try {
        final zoom = _map.camera.zoom < 15 ? 17.0 : _map.camera.zoom;
        _map.move(ll, zoom);
      } catch (_) {}
    }
  }

  void _flushHeld() {
    final held = _held;
    _held = null;
    if (held == null || _points.isEmpty) return;
    _storeFix(held);
  }

  void _acceptFix(Position pos) {
    final acc = pos.accuracy;
    if (acc.isFinite) _lastAccuracyM = acc;
    final accuracy = acc.isFinite ? acc : null;
    if (!decideCircuit8hFix(
      accuracyMeters: accuracy,
      maxAccuracyMeters: _acceptMeters,
    ).accepted) {
      _rejectedAccuracy++;
      if (mounted) setState(() {});
      return;
    }
    _rememberTight(pos);

    final held = _held;
    if (held == null) {
      _held = pos;
      return;
    }

    var dt = (pos.timestamp.millisecondsSinceEpoch -
            held.timestamp.millisecondsSinceEpoch) /
        1000;
    if (dt < 0) dt = 0;
    final speed = pos.speed;
    final decision = decideCircuit8hFix(
      accuracyMeters: accuracy,
      maxAccuracyMeters: _acceptMeters,
      jumpMeters: haversineMeters(
        held.latitude,
        held.longitude,
        pos.latitude,
        pos.longitude,
      ),
      dtSeconds: dt,
      reportedSpeedMps: speed.isFinite && speed >= 0 ? speed : null,
    );
    if (!decision.accepted) {
      _rejectedAccuracy++;
      if (mounted) setState(() {});
      return;
    }
    _storeFix(held);
    _held = pos;
  }

  void _recordNow() {
    if (!_warming || _saving) return;
    setState(() => _skipLock = true);
  }

  Future<void> _stopAndSave() async {
    if (_saving) return;
    _captureGen++;
    await _recordSub?.cancel();
    _recordSub = null;
    if (!mounted) return;
    _flushHeld();

    if (_points.length < 3) {
      final partial = _points.isNotEmpty;
      setState(() {
        _recording = false;
        _warming = false;
        _skipLock = false;
        _looseGate = false;
      });
      if (partial) {
        showAppSnackError(context, context.l10n.circuit8hNeedMorePoints);
      }
      await startLiveGps(map: _map, centerOnce: false);
      return;
    }

    setState(() {
      _recording = false;
      _saving = true;
    });

    final ended = DateTime.now().millisecondsSinceEpoch;
    final session = Circuit8hSession(
      id: 'c8h_${ended}_${widget.routeType.id}',
      routeType: widget.routeType,
      startedAtMs: _startedAtMs ?? ended,
      endedAtMs: ended,
      edge: _edge,
      points: List<Circuit8hPoint>.of(_points),
    );

    try {
      // Keep current markers + append this pass.
      final next = _project.withSession(session);
      await saveCircuit8hProject(next);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackError(context, '$e');
      await startLiveGps(map: _map, centerOnce: false);
    }
  }

  double _pathMeters() {
    if (_points.length < 2) return 0;
    var sum = 0.0;
    for (var i = 1; i < _points.length; i++) {
      sum += haversineMeters(
        _points[i - 1].lat,
        _points[i - 1].lng,
        _points[i].lat,
        _points[i].lng,
      );
    }
    return sum;
  }

  List<Marker> _overlayMarkers(BuildContext context) {
    final l10n = context.l10n;
    final out = <Marker>[];

    void pin(
      Circuit8hMarker m,
      Color color,
      IconData icon,
      String tip, {
      String? badge,
    }) {
      out.add(
        Marker(
          point: LatLng(m.lat, m.lng),
          width: 44,
          height: 48,
          alignment: Alignment.topCenter,
          child: Tooltip(
            message: tip,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.asphalt,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Icon(icon, color: color, size: 32),
              ],
            ),
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
        badge: l10n.circuit8hMarkStart,
      );
    }
    for (final cp in _project.checkpoints) {
      pin(
        cp,
        AppTheme.lineHot,
        Icons.location_on,
        cp.label ?? l10n.circuit8hMarkCheckpoint,
        badge: cp.label ?? 'CP',
      );
    }
    if (_project.finish != null) {
      pin(
        _project.finish!,
        AppTheme.signal,
        Icons.sports_score,
        l10n.circuit8hMarkFinish,
        badge: l10n.circuit8hMarkFinish,
      );
    }
    return out;
  }

  Widget _actionBar(AppLocalizations l10n) {
    final locked = _recording || _warming;
    return Material(
      color: AppTheme.asphalt.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.circuit8hEdgePick,
              style: GoogleFonts.rajdhani(
                color: AppTheme.mist,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _EdgeChoice(
                    label: l10n.circuit8hEdgeInner,
                    selected: _edge == Circuit8hTrackEdge.inner,
                    enabled: !locked,
                    onTap: () =>
                        setState(() => _edge = Circuit8hTrackEdge.inner),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _EdgeChoice(
                    label: l10n.circuit8hEdgeOuter,
                    selected: _edge == Circuit8hTrackEdge.outer,
                    enabled: !locked,
                    onTap: () =>
                        setState(() => _edge = Circuit8hTrackEdge.outer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_warming) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: AppTheme.asphalt,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _recordNow,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  l10n.circuit8hRecordNow,
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.signal,
                  foregroundColor: AppTheme.mist,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _stopAndSave,
                child: Text(
                  l10n.circuit8hCancelWait,
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _recording ? AppTheme.signal : _accent,
                  foregroundColor:
                      _recording ? AppTheme.mist : AppTheme.asphalt,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving
                    ? null
                    : (_recording ? _stopAndSave : _startRecording),
                icon: Icon(
                  _recording ? Icons.stop : Icons.radio_button_checked,
                ),
                label: Text(
                  _saving
                      ? l10n.circuit8hSaving                      : (_recording
                          ? l10n.circuit8hStopSave                          : l10n.circuit8hStartPass),
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final center = liveGps ?? const LatLng(20.67, -103.35);
    final meters = _pathMeters();
    final dist = meters < 1000
        ? '${meters.toStringAsFixed(0)} m'
        : '${(meters / 1000).toStringAsFixed(2)} km';
    final acc = _lastAccuracyM == null
        ? '—'
        : '±${_lastAccuracyM!.toStringAsFixed(0)} m';
    final status = _sampling
        ? l10n.circuit8hHoldStill(
            circuit8hMarkerMinSamples,
            circuit8hMaxAcceptAccuracyMeters.round(),
          )
        : _warming
        ? l10n.circuit8hWarming(acc)
        : _recording
            ? l10n.circuit8hRecordingStats(_points.length, dist, acc)
            : (_lastError ??
                l10n.circuit8hRecordIdle(
                  widget.routeType.label,
                  widget.passNumber,
                ));

    final latLngs = [
      for (final p in _points) LatLng(p.lat, p.lng),
    ];

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.circuit8hRecordTitle(
            widget.routeType.label,
            widget.passNumber,
          ),
        ),
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
                if (latLngs.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: latLngs,
                        color: _accent.withValues(alpha: 0.85),
                        strokeWidth: 3.5,
                      ),
                    ],
                  ),
                if (latLngs.isNotEmpty)
                  CircleLayer(
                    circles: [
                      for (final p in latLngs)
                        CircleMarker(
                          point: p,
                          radius: 4.5,
                          color: _accent.withValues(alpha: 0.95),
                          borderColor: AppTheme.mist.withValues(alpha: 0.5),
                          borderStrokeWidth: 0.7,
                        ),
                    ],
                  ),
                if (_overlayMarkers(context).isNotEmpty)
                  MarkerLayer(markers: _overlayMarkers(context)),
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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Text(
                        status,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _looseGate
                        ? l10n.circuit8hLooseNote(_acceptMeters.round())
                        : l10n.circuit8hPrecisionNote(
                            circuit8hMaxAcceptAccuracyMeters.round(),
                          ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.mist.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (_rejectedAccuracy > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.circuit8hRejected(_rejectedAccuracy),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.signal,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.circuit8hPassMarkersHint,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.mist.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _MarkerAction(
                                  icon: Icons.flag,
                                  label: l10n.circuit8hMarkStart,
                                  color: AppTheme.line,
                                  active: _project.hasStart,
                                  onTap: () => _placeMarker(
                                    Circuit8hMarkerKind.start,
                                  ),
                                  onClear: _project.hasStart
                                      ? _clearStart
                                      : null,
                                  clearTooltip: l10n.circuit8hClearMarker,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _MarkerAction(
                                  icon: Icons.location_on,
                                  label: l10n.circuit8hCheckpointN(_nextCp),
                                  color: AppTheme.lineHot,
                                  active: false,
                                  onTap: () => _placeMarker(
                                    Circuit8hMarkerKind.checkpoint,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: _MarkerAction(
                                  icon: Icons.sports_score,
                                  label: l10n.circuit8hMarkFinish,
                                  color: AppTheme.signal,
                                  active: _project.hasFinish,
                                  onTap: () => _placeMarker(
                                    Circuit8hMarkerKind.finish,
                                  ),
                                  onClear: _project.hasFinish
                                      ? _clearFinish
                                      : null,
                                  clearTooltip: l10n.circuit8hClearMarker,
                                ),
                              ),
                            ],
                          ),
                          if (_project.checkpoints.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final cp in _project.checkpoints)
                                  InputChip(
                                    label: Text(
                                      cp.label ?? 'CP',
                                      style: GoogleFonts.rajdhani(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      size: 16,
                                    ),
                                    onDeleted: () =>
                                        _deleteCheckpoint(cp.id),
                                    backgroundColor: AppTheme.asphalt,
                                    side: BorderSide(
                                      color: AppTheme.lineHot.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MapMyLocationChip(
                      onPressed: () {
                        setState(() => _follow = true);
                        recenterToLiveGpsOrNotify(_map);
                      },
                    ),
                  ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _actionBar(l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkerAction extends StatelessWidget {
  const _MarkerAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
    this.onClear,
    this.clearTooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: active
              ? color.withValues(alpha: 0.22)
              : AppTheme.asphalt,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            onLongPress: onClear,
            child: SizedBox(
              height: 56,
              child: Stack(
                children: [
                  Center(
                    child: Icon(icon, color: color, size: 28),
                  ),
                  if (onClear != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: onClear,
                        child: Tooltip(
                          message: clearTooltip ?? '',
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: AppTheme.mist.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.rajdhani(
            color: AppTheme.mist,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _EdgeChoice extends StatelessWidget {
  const _EdgeChoice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.line.withValues(alpha: 0.22) : AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.line : AppTheme.mist,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
              color: AppTheme.mist,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
