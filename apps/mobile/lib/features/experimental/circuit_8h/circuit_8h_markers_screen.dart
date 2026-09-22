import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/location_service.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_snack.dart';
import '../../maps/live_gps_map_mixin.dart';
import '../../maps/map_control_chip.dart';
import '../../ride_active/location_permission_gate.dart';
import 'circuit_8h_models.dart';
import 'circuit_8h_precision.dart';
import 'circuit_8h_store.dart';

/// Place start, finish, and checkpoints on the live map (GPS or tap).
class Circuit8hMarkersScreen extends ConsumerStatefulWidget {
  const Circuit8hMarkersScreen({super.key});

  @override
  ConsumerState<Circuit8hMarkersScreen> createState() =>
      _Circuit8hMarkersScreenState();
}

class _Circuit8hMarkersScreenState extends ConsumerState<Circuit8hMarkersScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  final LocationService _location = LocationService();

  Circuit8hProject _project = const Circuit8hProject();
  Circuit8hMarkerKind _kind = Circuit8hMarkerKind.start;
  bool _loading = true;
  bool _saving = false;
  bool _sampling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final project = await loadCircuit8hProject();
    if (!mounted) return;
    setState(() {
      _project = project;
      _loading = false;
    });
    final ok = await LocationPermissionGate.requestForRecording(context);
    if (!ok || !mounted) return;
    await startLiveGps(map: _map, centerOnce: true);
    _fitMarkers();
  }

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  Future<void> _persist(Circuit8hProject next) async {
    setState(() {
      _project = next;
      _saving = true;
    });
    try {
      await saveCircuit8hProject(next);
    } catch (e) {
      if (mounted) showAppSnackError(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _placeAtGps() async {
    if (_sampling || _saving) return;
    setState(() => _sampling = true);
    final Circuit8hMarkerFix? fix;
    try {
      final samples = await collectSurveySamples(
        read: () async {
          final pos = await _location.currentPosition();
          if (pos == null || !pos.accuracy.isFinite) return null;
          return Circuit8hSurveySample(
            lat: pos.latitude,
            lng: pos.longitude,
            accuracyM: pos.accuracy,
            tsMs: pos.timestamp.millisecondsSinceEpoch,
          );
        },
        cancelled: () => !mounted,
      );
      fix = medianMarkerFix(samples);
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
    await _place(fix.lat, fix.lng, accuracyM: fix.accuracyM);
  }

  Future<void> _place(double lat, double lng, {double? accuracyM}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'mk_${_kind.id}_$now';
    final marker = Circuit8hMarker(
      id: id,
      kind: _kind,
      lat: lat,
      lng: lng,
      tsMs: now,
      accuracyM: accuracyM,
      label: _kind == Circuit8hMarkerKind.checkpoint
          ? 'CP${_project.checkpointCount + 1}'
          : null,
    );

    final next = switch (_kind) {
      Circuit8hMarkerKind.start => _project.withStart(marker),
      Circuit8hMarkerKind.finish => _project.withFinish(marker),
      Circuit8hMarkerKind.checkpoint => _project.withCheckpoint(marker),
    };
    await _persist(next);
    try {
      _map.move(LatLng(lat, lng), _map.camera.zoom < 16 ? 17.0 : _map.camera.zoom);
    } catch (_) {}
  }

  Future<void> _clearStart() async {
    await _persist(_project.copyWith(clearStart: true));
  }

  Future<void> _clearFinish() async {
    await _persist(_project.copyWith(clearFinish: true));
  }

  Future<void> _deleteCheckpoint(String id) async {
    await _persist(_project.withoutCheckpoint(id));
  }

  void _fitMarkers() {
    final pts = <LatLng>[
      if (_project.start != null)
        LatLng(_project.start!.lat, _project.start!.lng),
      if (_project.finish != null)
        LatLng(_project.finish!.lat, _project.finish!.lng),
      for (final c in _project.checkpoints) LatLng(c.lat, c.lng),
      if (liveGps != null) liveGps!,
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final center = liveGps ??
        (_project.start != null
            ? LatLng(_project.start!.lat, _project.start!.lng)
            : const LatLng(20.67, -103.35));

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(l10n.circuit8hMarkersTitle),
        actions: [
          IconButton(
            tooltip: l10n.circuit8hFitMarkers,
            onPressed: _fitMarkers,
            icon: const Icon(Icons.fit_screen_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 17,
                      onTap: (tap, latLng) {
                        unawaited(
                          _place(latLng.latitude, latLng.longitude),
                        );
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rawthrottle.riderlab',
                      ),
                      MarkerLayer(markers: _mapMarkers()),
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
                        Material(
                          color: AppTheme.asphaltElevated.withValues(
                            alpha: 0.94,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  l10n.circuit8hMarkersHint,
                                  style: GoogleFonts.rajdhani(
                                    color: AppTheme.mist,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _KindChip(
                                      selected:
                                          _kind == Circuit8hMarkerKind.start,
                                      label: l10n.circuit8hMarkStart,
                                      color: AppTheme.line,
                                      onTap: () => setState(
                                        () => _kind =
                                            Circuit8hMarkerKind.start,
                                      ),
                                    ),
                                    _KindChip(
                                      selected:
                                          _kind == Circuit8hMarkerKind.finish,
                                      label: l10n.circuit8hMarkFinish,
                                      color: AppTheme.signal,
                                      onTap: () => setState(
                                        () => _kind =
                                            Circuit8hMarkerKind.finish,
                                      ),
                                    ),
                                    _KindChip(
                                      selected: _kind ==
                                          Circuit8hMarkerKind.checkpoint,
                                      label: l10n.circuit8hMarkCheckpoint,
                                      color: AppTheme.lineHot,
                                      onTap: () => setState(
                                        () => _kind =
                                            Circuit8hMarkerKind.checkpoint,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.lineHot,
                                    foregroundColor: AppTheme.asphalt,
                                  ),
                                  onPressed: (_saving || _sampling) ? null : _placeAtGps,
                                  icon: const Icon(Icons.my_location),
                                  label: Text(
                                    _sampling
                                        ? l10n.circuit8hHoldStill(
                                            circuit8hMarkerMinSamples,
                                            circuit8hMaxAcceptAccuracyMeters
                                                .round(),
                                          )
                                        : l10n.circuit8hPlaceAtGps,
                                    style: GoogleFonts.rajdhani(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: MapMyLocationChip(
                            onPressed: () =>
                                recenterToLiveGpsOrNotify(_map),
                          ),
                        ),
                        const Spacer(),
                        Material(
                          color: AppTheme.asphaltElevated.withValues(
                            alpha: 0.94,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _StatusRow(
                                  label: l10n.circuit8hMarkStart,
                                  value: _project.hasStart
                                      ? l10n.circuit8hMarkerSet
                                      : l10n.circuit8hMarkerMissing,
                                  set: _project.hasStart,
                                  onClear: _project.hasStart
                                      ? _clearStart
                                      : null,
                                  clearLabel: l10n.circuit8hClearMarker,
                                ),
                                _StatusRow(
                                  label: l10n.circuit8hMarkFinish,
                                  value: _project.hasFinish
                                      ? l10n.circuit8hMarkerSet
                                      : l10n.circuit8hMarkerMissing,
                                  set: _project.hasFinish,
                                  onClear: _project.hasFinish
                                      ? _clearFinish
                                      : null,
                                  clearLabel: l10n.circuit8hClearMarker,
                                ),
                                Text(
                                  l10n.circuit8hCheckpointCount(
                                    _project.checkpointCount,
                                  ),
                                  style: GoogleFonts.rajdhani(
                                    color: AppTheme.mist,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                if (_project.checkpoints.isNotEmpty)
                                  ...[
                                    for (final cp in _project.checkpoints)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        title: Text(
                                          cp.label ?? cp.id,
                                          style: GoogleFonts.rajdhani(
                                            color: AppTheme.mist,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        trailing: IconButton(
                                          tooltip: l10n.circuit8hClearMarker,
                                          onPressed: () =>
                                              _deleteCheckpoint(cp.id),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                              ],
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

  List<Marker> _mapMarkers() {
    final out = <Marker>[];
    void add(Circuit8hMarker m, Color color, IconData icon, String tip) {
      out.add(
        Marker(
          point: LatLng(m.lat, m.lng),
          width: 40,
          height: 40,
          child: Tooltip(
            message: tip,
            child: Icon(icon, color: color, size: 34),
          ),
        ),
      );
    }

    if (_project.start != null) {
      add(
        _project.start!,
        AppTheme.line,
        Icons.flag,
        context.l10n.circuit8hMarkStart,
      );
    }
    if (_project.finish != null) {
      add(
        _project.finish!,
        AppTheme.signal,
        Icons.sports_score,
        context.l10n.circuit8hMarkFinish,
      );
    }
    for (final cp in _project.checkpoints) {
      add(
        cp,
        AppTheme.lineHot,
        Icons.location_on,
        cp.label ?? context.l10n.circuit8hMarkCheckpoint,
      );
    }
    return out;
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.selected,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontWeight: FontWeight.w700,
          color: selected ? AppTheme.asphalt : AppTheme.mist,
        ),
      ),
      selectedColor: color,
      backgroundColor: AppTheme.asphalt,
      side: BorderSide(color: color.withValues(alpha: 0.7)),
      onSelected: (_) => onTap(),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.set,
    required this.clearLabel,
    this.onClear,
  });

  final String label;
  final String value;
  final bool set;
  final String clearLabel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: GoogleFonts.rajdhani(
          color: AppTheme.mist,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        value,
        style: GoogleFonts.rajdhani(
          color: set
              ? AppTheme.line
              : AppTheme.mist.withValues(alpha: 0.65),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      trailing: onClear == null
          ? null
          : IconButton(
              tooltip: clearLabel,
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
    );
  }
}
