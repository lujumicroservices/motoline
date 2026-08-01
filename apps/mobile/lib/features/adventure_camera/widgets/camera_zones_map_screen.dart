import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/track_point.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../models/camera_zone.dart';

/// Fullscreen map to place multiple GoPro start/stop geofences on a track.
class CameraZonesMapScreen extends StatefulWidget {
  const CameraZonesMapScreen({
    super.key,
    required this.initialZones,
    this.trackPoints = const [],
  });

  final List<CameraZone> initialZones;
  final List<TrackPoint> trackPoints;

  @override
  State<CameraZonesMapScreen> createState() => _CameraZonesMapScreenState();
}

class _CameraZonesMapScreenState extends State<CameraZonesMapScreen> {
  final MapController _map = MapController();
  final _uuid = const Uuid();

  late List<CameraZone> _zones;
  CameraZoneAction _placeAction = CameraZoneAction.start;

  @override
  void initState() {
    super.initState();
    _zones = List.of(widget.initialZones);
  }

  void _onTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _zones.add(
        CameraZone(
          id: _uuid.v4(),
          latitude: latlng.latitude,
          longitude: latlng.longitude,
          action: _placeAction,
        ),
      );
    });
  }

  void _removeZone(String id) {
    setState(() => _zones.removeWhere((z) => z.id == id));
  }

  void _fit() {
    final pts = <LatLng>[
      for (final p in widget.trackPoints) LatLng(p.latitude, p.longitude),
      for (final z in _zones) LatLng(z.latitude, z.longitude),
    ];
    if (pts.isEmpty) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.fromLTRB(40, 140, 40, 220),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final track = widget.trackPoints;
    LatLng center;
    LatLngBounds? bounds;
    if (track.isNotEmpty) {
      bounds = LatLngBounds.fromPoints([
        for (final p in track) LatLng(p.latitude, p.longitude),
      ]);
      center = LatLng(
        track[track.length ~/ 2].latitude,
        track[track.length ~/ 2].longitude,
      );
    } else if (_zones.isNotEmpty) {
      center = LatLng(_zones.first.latitude, _zones.first.longitude);
    } else {
      center = const LatLng(19.43, -99.13);
    }

    final starts = _zones.where((z) => z.action == CameraZoneAction.start);
    final stops = _zones.where((z) => z.action == CameraZoneAction.stop);

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
                        padding: const EdgeInsets.fromLTRB(40, 140, 40, 220),
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
                if (track.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          for (final p in track)
                            LatLng(p.latitude, p.longitude),
                        ],
                        color: AppTheme.steel.withValues(alpha: 0.75),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                CircleLayer(
                  circles: [
                    for (final z in _zones)
                      CircleMarker(
                        point: LatLng(z.latitude, z.longitude),
                        radius: z.radiusMeters,
                        useRadiusInMeter: true,
                        color: (z.action == CameraZoneAction.start
                                ? AppTheme.line
                                : AppTheme.signal)
                            .withValues(alpha: 0.22),
                        borderColor: z.action == CameraZoneAction.start
                            ? AppTheme.line
                            : AppTheme.signal,
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final z in _zones)
                      Marker(
                        point: LatLng(z.latitude, z.longitude),
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onLongPress: () => _removeZone(z.id),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: z.action == CameraZoneAction.start
                                  ? AppTheme.line
                                  : AppTheme.signal,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.mist,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              z.action == CameraZoneAction.start ? '▶' : '■',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.asphalt,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
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
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.labAdventureCameraZonesTitle,
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: _fit,
                        icon: const Icon(Icons.fit_screen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppTheme.asphaltElevated.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.labAdventureCameraZonesHelp,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<CameraZoneAction>(
                            segments: [
                              ButtonSegment(
                                value: CameraZoneAction.start,
                                label: Text(l10n.labAdventureCameraZoneStart),
                                icon: const Icon(Icons.fiber_manual_record,
                                    size: 14),
                              ),
                              ButtonSegment(
                                value: CameraZoneAction.stop,
                                label: Text(l10n.labAdventureCameraZoneStop),
                                icon: const Icon(Icons.stop, size: 14),
                              ),
                            ],
                            selected: {_placeAction},
                            onSelectionChanged: (set) {
                              setState(() => _placeAction = set.first);
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.labAdventureCameraZoneStart}: ${starts.length}'
                            '  ·  ${l10n.labAdventureCameraZoneStop}: ${stops.length}',
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.mist,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_zones.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(_zones.clear),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(l10n.labAdventureCameraZonesClear),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_zones),
                      child: Text(l10n.labAdventureCameraZonesSave),
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
