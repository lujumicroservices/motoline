import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';
import 'watch_models.dart';
import 'watch_providers.dart';

class WatchViewerScreen extends ConsumerStatefulWidget {
  const WatchViewerScreen({super.key, required this.session});

  final WatchSession session;

  @override
  ConsumerState<WatchViewerScreen> createState() => _WatchViewerScreenState();
}

class _WatchViewerScreenState extends ConsumerState<WatchViewerScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  WatchPosition? _pos;
  List<WatchEvent> _events = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(watchRepositoryProvider);
    final pos = await repo.getPosition(widget.session.id);
    final events = await repo.listEvents(widget.session.id);
    if (!mounted) return;
    setState(() {
      _pos = pos;
      _events = events;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = widget.session.riderDisplayName ?? l10n.familyRiderFallback;
    final pos = _pos;
    final center = pos == null
        ? const LatLng(20.67, -103.35)
        : LatLng(pos.latitude, pos.longitude);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (pos != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      pos.isStale
                          ? l10n.familyNoSignalSince(
                              DateFormat.Hm().format(pos.updatedAt.toLocal()),
                            )
                          : l10n.familyLastSeen(
                              DateFormat.Hm().format(pos.updatedAt.toLocal()),
                            ),
                      style: GoogleFonts.rajdhani(
                        color: pos.isStale ? AppTheme.steel : AppTheme.line,
                        fontSize: 15,
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FlutterMap(
                          mapController: _map,
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: pos == null ? 11 : 14,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.rawthrottle.riderlab',
                            ),
                            if (pos != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(pos.latitude, pos.longitude),
                                    width: 40,
                                    height: 40,
                                    child: Icon(
                                      pos.isStale
                                          ? Icons.location_off
                                          : Icons.navigation,
                                      color: pos.isStale
                                          ? AppTheme.steel
                                          : AppTheme.line,
                                    ),
                                  ),
                                ],
                              ),
                            liveGpsMapChild(),
                          ],
                        ),
                      ),
                      myLocationOverlay(_map),
                    ],
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final e in _events)
                        Text(
                          '${DateFormat.Hm().format(e.createdAt.toLocal())} · ${e.kind}',
                          style: const TextStyle(color: AppTheme.steel),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
