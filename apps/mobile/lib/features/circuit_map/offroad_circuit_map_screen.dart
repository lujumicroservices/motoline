import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:ride_core/ride_core.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../maps/map_control_chip.dart';
import 'offroad_circuit_advice_text.dart';
import 'offroad_circuit_store.dart';

enum _EditLayer { outer, inner, line, gate }

const _outerColor = Color(0xFFFF5A2A);
const _innerColor = AppTheme.line;
const _lineColor = Color(0xFF4CC9F0);
const _gateColor = AppTheme.lineHot;

/// Walk the outside and inside edges of an offroad circuit, then see what
/// else the map still needs.
class OffroadCircuitMapScreen extends StatefulWidget {
  const OffroadCircuitMapScreen({super.key});

  @override
  State<OffroadCircuitMapScreen> createState() =>
      _OffroadCircuitMapScreenState();
}

class _OffroadCircuitMapScreenState extends State<OffroadCircuitMapScreen> {
  final MapController _map = MapController();
  final TextEditingController _name = TextEditingController();
  final ValueNotifier<LatLng?> _gps = ValueNotifier<LatLng?>(null);

  OffroadCircuitSurvey _survey = const OffroadCircuitSurvey();
  _EditLayer _layer = _EditLayer.outer;
  bool _recording = false;
  bool _satellite = true;
  int _droppedFixes = 0;
  bool _centered = false;
  StreamSubscription<Position>? _gpsSub;

  @override
  void initState() {
    super.initState();
    _restore();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGps());
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _gps.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    OffroadCircuitSurvey? saved;
    try {
      saved = await loadOffroadCircuitSurvey();
    } catch (_) {
      return;
    }
    if (!mounted || saved == null) return;
    final loaded = saved;
    setState(() {
      _survey = loaded;
      _name.text = loaded.name;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fit();
    });
  }

  Future<void> _save() async {
    try {
      await saveOffroadCircuitSurvey(_survey);
    } catch (_) {
      // The in-memory survey still works if local storage is unavailable.
    }
  }

  Future<void> _startGps() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final once = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      if (!mounted) return;
      _onPosition(once);
      await _gpsSub?.cancel();
      _gpsSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 2,
        ),
      ).listen(_onPosition);
    } catch (_) {
      // Tapping the map still works without a fix.
    }
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final here = LatLng(pos.latitude, pos.longitude);
    _gps.value = here;
    if (!_centered && _survey.outer.isEmpty && _survey.inner.isEmpty) {
      _centered = true;
      _map.move(here, 17);
    }
    if (!_recording || _layer == _EditLayer.gate) return;
    final next = CircuitPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      altitudeM: pos.altitude,
    );
    final existing = _pointsOf(_layer);
    final decision = considerCircuitSample(existing: existing, next: next);
    if (decision.reject == CircuitSampleReject.poorAccuracy) {
      setState(() => _droppedFixes++);
    }
    if (!decision.keep) return;
    setState(() {
      _survey = _withPoints(_layer, [...existing, next]);
    });
    _save();
  }

  List<CircuitPoint> _pointsOf(_EditLayer layer) {
    return switch (layer) {
      _EditLayer.outer => _survey.outer,
      _EditLayer.inner => _survey.inner,
      _EditLayer.line => _survey.racingLine,
      _EditLayer.gate => const [],
    };
  }

  OffroadCircuitSurvey _withPoints(
    _EditLayer layer,
    List<CircuitPoint> points,
  ) {
    return switch (layer) {
      _EditLayer.outer => _survey.copyWith(outer: points),
      _EditLayer.inner => _survey.copyWith(inner: points),
      _EditLayer.line => _survey.copyWith(racingLine: points),
      _EditLayer.gate => _survey,
    };
  }

  void _setLayer(_EditLayer layer) {
    if (_recording) _recording = false;
    setState(() => _layer = layer);
  }

  void _onTap(TapPosition _, LatLng latlng) {
    final point = CircuitPoint(lat: latlng.latitude, lng: latlng.longitude);
    setState(() {
      if (_layer == _EditLayer.gate) {
        if (!_survey.hasGate && _survey.gateOuter != null) {
          _survey = _survey.copyWith(gateInner: point);
        } else {
          _survey = _survey.copyWith(gateOuter: point, clearGateInner: true);
        }
        return;
      }
      final existing = _pointsOf(_layer);
      if (existing.isNotEmpty &&
          circuitDistanceMeters(existing.last, point) < 1) {
        return;
      }
      _survey = _withPoints(_layer, [...existing, point]);
    });
    _save();
  }

  void _undo() {
    setState(() {
      if (_layer == _EditLayer.gate) {
        if (_survey.gateInner != null) {
          _survey = _survey.copyWith(clearGateInner: true);
        } else {
          _survey = _survey.copyWith(clearGateOuter: true);
        }
        return;
      }
      final existing = _pointsOf(_layer);
      if (existing.isEmpty) return;
      _survey = _withPoints(_layer, existing.sublist(0, existing.length - 1));
    });
    _save();
  }

  void _closeRing() {
    if (_layer != _EditLayer.outer && _layer != _EditLayer.inner) return;
    final existing = _pointsOf(_layer);
    final closed = closeCircuitRing(existing);
    if (identical(closed, existing)) return;
    setState(() => _survey = _withPoints(_layer, closed));
    _save();
  }

  Future<void> _clearLayer() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(l10n.offroadClearTitle),
        content: Text(l10n.offroadClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.offroadClearLayer),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _recording = false;
      if (_layer == _EditLayer.gate) {
        _survey = _survey.copyWith(clearGateOuter: true, clearGateInner: true);
      } else {
        _survey = _withPoints(_layer, const []);
      }
    });
    _save();
  }

  void _fit() {
    final points = <LatLng>[
      for (final p in [
        ..._survey.outer,
        ..._survey.inner,
        ..._survey.racingLine,
      ])
        LatLng(p.lat, p.lng),
      if (_survey.gateOuter != null)
        LatLng(_survey.gateOuter!.lat, _survey.gateOuter!.lng),
      if (_survey.gateInner != null)
        LatLng(_survey.gateInner!.lat, _survey.gateInner!.lng),
    ];
    if (points.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(28, 120, 28, 220),
        maxZoom: 18,
      ),
    );
  }

  void _zoomBy(double delta) {
    final cam = _map.camera;
    _map.move(cam.center, (cam.zoom + delta).clamp(3, 19));
  }

  void _openAdvice() {
    final assessment = assessOffroadCircuit(_survey);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.asphaltElevated,
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.78;
        return SizedBox(
          height: height,
          child: _AdviceSheet(
            name: _name,
            assessment: assessment,
            onName: (value) {
              setState(() => _survey = _survey.copyWith(name: value));
              _save();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final assessment = assessOffroadCircuit(_survey);
    final activeCount = _layer == _EditLayer.gate
        ? (_survey.hasGate ? 2 : (_survey.gateOuter == null ? 0 : 1))
        : _pointsOf(_layer).length;

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(19.43, -99.13),
                initialZoom: 15,
                maxZoom: 19,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: _satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rawthrottle.riderlab',
                ),
                if (_survey.outer.length >= 3 && _survey.inner.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _latLngs(_survey.outer),
                        holePointsList: [_latLngs(_survey.inner)],
                        color: _lineColor.withValues(alpha: 0.22),
                        borderStrokeWidth: 0,
                      ),
                    ],
                  ),
                PolylineLayer(
                  polylines: [
                    if (_survey.outer.length >= 2)
                      Polyline(
                        points: _latLngs(_survey.outer),
                        strokeWidth: 4,
                        color: _outerColor,
                      ),
                    if (_survey.inner.length >= 2)
                      Polyline(
                        points: _latLngs(_survey.inner),
                        strokeWidth: 4,
                        color: _innerColor,
                      ),
                    if (_survey.racingLine.length >= 2)
                      Polyline(
                        points: _latLngs(_survey.racingLine),
                        strokeWidth: 3,
                        color: _lineColor,
                      ),
                    if (_survey.hasGate)
                      Polyline(
                        points: [
                          LatLng(
                            _survey.gateOuter!.lat,
                            _survey.gateOuter!.lng,
                          ),
                          LatLng(
                            _survey.gateInner!.lat,
                            _survey.gateInner!.lng,
                          ),
                        ],
                        strokeWidth: 4,
                        color: _gateColor,
                      ),
                  ],
                ),
                MarkerLayer(markers: _markers()),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _gps,
                  builder: (context, gps, _) {
                    if (gps == null) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: gps,
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C8DFF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _chrome(
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.back,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _chrome(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          _survey.name.isEmpty
                              ? l10n.offroadMapTitle
                              : _survey.name,
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _chrome(
                    child: InkWell(
                      onTap: _openAdvice,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Text(
                          '${assessment.score}',
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            color: assessment.ready
                                ? _innerColor
                                : AppTheme.lineHot,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 88,
            child: SafeArea(
              child: Column(
                children: [
                  MapControlChip(
                    icon: Icons.add,
                    tooltip: l10n.zoomIn,
                    onPressed: () => _zoomBy(1),
                  ),
                  const SizedBox(height: 8),
                  MapControlChip(
                    icon: Icons.remove,
                    tooltip: l10n.zoomOut,
                    onPressed: () => _zoomBy(-1),
                  ),
                  const SizedBox(height: 8),
                  MapControlChip(
                    icon: Icons.fit_screen,
                    tooltip: l10n.fitRide,
                    onPressed: _fit,
                  ),
                  const SizedBox(height: 8),
                  MapControlChip(
                    icon: Icons.my_location,
                    tooltip: l10n.myLocation,
                    onPressed: () {
                      final here = _gps.value;
                      if (here == null) return;
                      _map.move(
                        here,
                        _map.camera.zoom < 16 ? 17 : _map.camera.zoom,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  MapControlChip(
                    icon: _satellite ? Icons.satellite_alt : Icons.map_outlined,
                    tooltip: _satellite
                        ? l10n.offroadSatellite
                        : l10n.offroadStreets,
                    onPressed: () => setState(() => _satellite = !_satellite),
                  ),
                ],
              ),
            ),
          ),
          if (_satellite)
            const Positioned(
              left: 12,
              top: 72,
              child: SafeArea(
                child: Text(
                  'Esri, Maxar, Earthstar Geographics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _EditorPanel(
              layer: _layer,
              recording: _recording,
              activeCount: activeCount,
              droppedFixes: _droppedFixes,
              assessment: assessment,
              direction: _survey.direction,
              gateOuterSet: _survey.gateOuter != null,
              gateReady: _survey.hasGate,
              onLayer: _setLayer,
              onRecord: () => setState(() => _recording = !_recording),
              onUndo: _undo,
              onCloseRing: _closeRing,
              onClear: _clearLayer,
              onAdvice: _openAdvice,
              onDirection: (direction) {
                setState(
                  () => _survey = _survey.copyWith(direction: direction),
                );
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _markers() {
    final markers = <Marker>[];
    void dot(CircuitPoint? point, Color color, String label) {
      if (point == null) return;
      markers.add(
        Marker(
          point: LatLng(point.lat, point.lng),
          width: 28,
          height: 28,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.asphalt,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_survey.outer.isNotEmpty) dot(_survey.outer.first, _outerColor, 'A');
    if (_survey.inner.isNotEmpty) dot(_survey.inner.first, _innerColor, 'A');
    dot(_survey.gateOuter, _gateColor, 'E');
    dot(_survey.gateInner, _gateColor, 'I');
    return markers;
  }
}

List<LatLng> _latLngs(List<CircuitPoint> points) => [
  for (final p in points) LatLng(p.lat, p.lng),
];

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({
    required this.layer,
    required this.recording,
    required this.activeCount,
    required this.droppedFixes,
    required this.assessment,
    required this.direction,
    required this.gateOuterSet,
    required this.gateReady,
    required this.onLayer,
    required this.onRecord,
    required this.onUndo,
    required this.onCloseRing,
    required this.onClear,
    required this.onAdvice,
    required this.onDirection,
  });

  final _EditLayer layer;
  final bool recording;
  final int activeCount;
  final int droppedFixes;
  final CircuitAssessment assessment;
  final TravelDirection direction;
  final bool gateOuterSet;
  final bool gateReady;
  final ValueChanged<_EditLayer> onLayer;
  final VoidCallback onRecord;
  final VoidCallback onUndo;
  final VoidCallback onCloseRing;
  final VoidCallback onClear;
  final VoidCallback onAdvice;
  final ValueChanged<TravelDirection> onDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hint = switch (layer) {
      _EditLayer.outer => l10n.offroadHintOuter,
      _EditLayer.inner => l10n.offroadHintInner,
      _EditLayer.line => l10n.offroadHintLine,
      _EditLayer.gate =>
        '${l10n.offroadHintGate} ${gateReady ? l10n.offroadGateReady : (gateOuterSet ? l10n.offroadGateNeedInner : l10n.offroadGateNeedOuter)}',
    };
    final gap = switch (layer) {
      _EditLayer.outer => assessment.outerClosureM,
      _EditLayer.inner => assessment.innerClosureM,
      _ => null,
    };
    final closure = gap == null
        ? null
        : (gap <= kCircuitCloseMeters
              ? l10n.offroadClosed
              : l10n.offroadGapHint(gap.round()));

    return Material(
      color: AppTheme.asphaltElevated.withValues(alpha: 0.96),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.46,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _layerChip(
                      l10n.offroadLayerOuter,
                      _EditLayer.outer,
                      _outerColor,
                    ),
                    _layerChip(
                      l10n.offroadLayerInner,
                      _EditLayer.inner,
                      _innerColor,
                    ),
                    _layerChip(
                      l10n.offroadLayerLine,
                      _EditLayer.line,
                      _lineColor,
                    ),
                    _layerChip(
                      l10n.offroadLayerGate,
                      _EditLayer.gate,
                      _gateColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  hint,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.mist,
                    fontSize: 15,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    l10n.offroadPoints(activeCount),
                    ?closure,
                    if (droppedFixes > 0) l10n.offroadDropped(droppedFixes),
                  ].join(' · '),
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (layer != _EditLayer.gate)
                      FilledButton.icon(
                        onPressed: onRecord,
                        style: FilledButton.styleFrom(
                          backgroundColor: recording
                              ? AppTheme.signal
                              : _innerColor,
                          foregroundColor: AppTheme.asphalt,
                        ),
                        icon: Icon(
                          recording ? Icons.stop : Icons.fiber_manual_record,
                        ),
                        label: Text(
                          recording
                              ? l10n.offroadRecording
                              : l10n.offroadRecord,
                        ),
                      ),
                    OutlinedButton(
                      onPressed: onUndo,
                      child: Text(l10n.offroadUndo),
                    ),
                    if (layer == _EditLayer.outer || layer == _EditLayer.inner)
                      OutlinedButton(
                        onPressed: onCloseRing,
                        child: Text(l10n.offroadCloseRing),
                      ),
                    TextButton(
                      onPressed: onClear,
                      child: Text(l10n.offroadClearLayer),
                    ),
                    TextButton(
                      onPressed: onAdvice,
                      child: Text(l10n.offroadAdviceTitle),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      direction == TravelDirection.unset
                          ? '${l10n.offroadDirection} · ${l10n.offroadDirectionUnset}'
                          : l10n.offroadDirection,
                      style: GoogleFonts.rajdhani(color: AppTheme.steel),
                    ),
                    ChoiceChip(
                      label: Text(l10n.offroadClockwise),
                      selected: direction == TravelDirection.clockwise,
                      onSelected: (_) => onDirection(TravelDirection.clockwise),
                    ),
                    ChoiceChip(
                      label: Text(l10n.offroadCounterclockwise),
                      selected: direction == TravelDirection.counterclockwise,
                      onSelected: (_) =>
                          onDirection(TravelDirection.counterclockwise),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _layerChip(String label, _EditLayer value, Color color) {
    final selected = layer == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.28),
      labelStyle: GoogleFonts.exo2(
        fontWeight: FontWeight.w700,
        color: selected ? color : AppTheme.mist,
        fontSize: 13,
      ),
      onSelected: (_) => onLayer(value),
    );
  }
}

class _AdviceSheet extends StatelessWidget {
  const _AdviceSheet({
    required this.name,
    required this.assessment,
    required this.onName,
  });

  final TextEditingController name;
  final CircuitAssessment assessment;
  final ValueChanged<String> onName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.steel.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.offroadAdviceTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          assessment.ready ? l10n.offroadReady : l10n.offroadNotReady,
          style: GoogleFonts.rajdhani(
            color: assessment.ready ? _innerColor : AppTheme.lineHot,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l10n.offroadQuality(assessment.score),
          style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          onChanged: onName,
          decoration: InputDecoration(
            hintText: l10n.offroadNameHint,
            helperText: l10n.offroadSavedLocal,
          ),
        ),
        const SizedBox(height: 8),
        if (assessment.outerLengthM != null)
          Text(
            l10n.offroadStatLengths(
              assessment.outerLengthM!.round(),
              (assessment.innerLengthM ?? 0).round(),
            ),
            style: GoogleFonts.rajdhani(color: AppTheme.mist),
          ),
        if (assessment.minWidthM != null && assessment.maxWidthM != null)
          Text(
            l10n.offroadStatWidth(
              assessment.minWidthM!.round(),
              assessment.maxWidthM!.round(),
            ),
            style: GoogleFonts.rajdhani(color: AppTheme.mist),
          ),
        if (assessment.outerClosureM != null ||
            assessment.innerClosureM != null)
          Text(
            l10n.offroadStatGap(
              (assessment.outerClosureM ?? 0).round(),
              (assessment.innerClosureM ?? 0).round(),
            ),
            style: GoogleFonts.rajdhani(color: AppTheme.steel),
          ),
        const SizedBox(height: 12),
        for (final advice in assessment.advice) ...[
          _AdviceTile(advice: advice),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AdviceTile extends StatelessWidget {
  const _AdviceTile({required this.advice});

  final CircuitAdvice advice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = switch (advice.level) {
      CircuitAdviceLevel.required => AppTheme.signal,
      CircuitAdviceLevel.recommended => AppTheme.lineHot,
      CircuitAdviceLevel.tip => AppTheme.steel,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offroadAdviceLevelLabel(l10n, advice.level),
            style: GoogleFonts.exo2(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            offroadAdviceText(l10n, advice),
            style: GoogleFonts.rajdhani(fontSize: 15, height: 1.3),
          ),
        ],
      ),
    );
  }
}

Widget _chrome({required Widget child}) {
  return Material(
    color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(12),
    child: child,
  );
}
