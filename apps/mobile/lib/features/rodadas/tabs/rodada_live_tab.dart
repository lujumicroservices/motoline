import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/routing/off_route.dart';
import '../../../core/services/directions_service.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../maps/live_gps_map_mixin.dart';
import '../../watch/active_watch_panel.dart';
import '../../watch/watch_repository.dart';
import '../models/rodada_models.dart';
import '../photos/ride_photo_capture.dart';
import '../rodada_itinerary.dart';
import '../rodada_itinerary_map.dart';
import '../rodada_providers.dart';

/// Live pack map. Watching [rodadaLivePositionsProvider] starts GPS publish;
/// leaving this tab disposes the publisher and clears your cloud position.
class RodadaLiveTab extends ConsumerWidget {
  const RodadaLiveTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final membership = ref.watch(myRodadaMembershipProvider(rodadaId));

    return Column(
      children: [
        membership.maybeWhen(
          data: (m) {
            if (m?.shareLive == true) {
              return Material(
                color: AppTheme.line.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sensors, color: AppTheme.line, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.sharingLocationBanner,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Material(
              color: AppTheme.asphaltElevated,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.liveMapViewOnly,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.steel,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(rodadaRepositoryProvider).updateMySharing(
                              rodadaId: rodadaId,
                              shareLive: true,
                            );
                        ref.invalidate(myRodadaMembershipProvider(rodadaId));
                      },
                      child: Text(l10n.shareLive),
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        ActiveWatchPanel(
          localRideId: WatchRepository.rodadaLocalRideId(rodadaId),
          compact: true,
        ),
        Expanded(
          child: _RodadaLiveMapHost(
            rodadaId: rodadaId,
            isHost: membership.maybeWhen(
              data: (m) => m?.isHost == true,
              orElse: () => false,
            ),
          ),
        ),
      ],
    );
  }
}

/// Owns riverpod watches but keeps [FlutterMap] mounted in a child State.
class _RodadaLiveMapHost extends ConsumerWidget {
  const _RodadaLiveMapHost({
    required this.rodadaId,
    required this.isHost,
  });

  final String rodadaId;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(rodadaLivePositionsProvider(rodadaId));
    final stops = ref.watch(rodadaStopsProvider(rodadaId));
    final overview = ref.watch(rodadaOverviewProvider(rodadaId));

    final meetup = overview.maybeWhen(
      data: (r) => r != null && r.hasMeetup
          ? LatLng(r.meetupLat!, r.meetupLng!)
          : null,
      orElse: () => null,
    );
    final finish = overview.maybeWhen(
      data: (r) => r != null && r.hasFinish
          ? LatLng(r.finishLat!, r.finishLng!)
          : null,
      orElse: () => null,
    );
    final stopList = stops.maybeWhen(
      data: (s) => s,
      orElse: () => const <RodadaStop>[],
    );
    final list = positions.maybeWhen(
      data: (l) => l,
      orElse: () => const <RodadaLivePosition>[],
    );
    final loading = positions.isLoading && list.isEmpty;
    final Object? error = positions.hasError ? positions.error : null;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && list.isEmpty) {
      return Center(child: Text('$error'));
    }

    return Stack(
      children: [
        _RodadaLiveMap(
          meetup: meetup,
          finish: finish,
          stops: stopList,
          positions: list,
          routedLine: overview.maybeWhen(
            data: (r) => r?.decodedRoute ?? const <LatLng>[],
            orElse: () => const <LatLng>[],
          ),
        ),
        if (list.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Material(
              color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  context.l10n.noLiveRidersYet,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          bottom: isHost ? 92 : 24,
          child: RidePhotoShutterButton(
            rodadaId: rodadaId,
            fallbackLat: list.isEmpty ? null : list.first.latitude,
            fallbackLng: list.isEmpty ? null : list.first.longitude,
          ),
        ),
        if (isHost)
          Positioned(
            right: 12,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'rodada_stop',
              onPressed: () => _addStop(context, ref, rodadaId),
              icon: const Icon(Icons.add_location_alt),
              label: Text(context.l10n.stopFab),
            ),
          ),
      ],
    );
  }
}

Future<void> _addStop(
  BuildContext context,
  WidgetRef ref,
  String rodadaId,
) async {
  final l10n = context.l10n;
  final titleCtrl = TextEditingController(text: l10n.gasBreakDefault);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.addStop),
      content: TextField(
        controller: titleCtrl,
        decoration: InputDecoration(labelText: l10n.stopTitleLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.dropAtMyGps),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    final pos = await Geolocator.getCurrentPosition();
    await ref.read(rodadaRepositoryProvider).addStop(
          rodadaId: rodadaId,
          title: titleCtrl.text.trim().isEmpty
              ? l10n.stopDefault
              : titleCtrl.text.trim(),
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
    ref.invalidate(rodadaStopsProvider(rodadaId));
    unawaited(
      ref.read(rodadaRepositoryProvider).refreshStoredRoute(
            rodadaId,
            directions: ref.read(directionsServiceProvider),
          ).then((_) {
        ref.invalidate(rodadaOverviewProvider(rodadaId));
      }),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}

/// Stable [FlutterMap] — tiles stay mounted; markers update without remount.
class _RodadaLiveMap extends StatefulWidget {
  const _RodadaLiveMap({
    required this.meetup,
    required this.finish,
    required this.stops,
    required this.positions,
    this.routedLine = const [],
  });

  final LatLng? meetup;
  final LatLng? finish;
  final List<RodadaStop> stops;
  final List<RodadaLivePosition> positions;
  final List<LatLng> routedLine;

  @override
  State<_RodadaLiveMap> createState() => _RodadaLiveMapState();
}

class _RodadaLiveMapState extends State<_RodadaLiveMap> with LiveGpsMapMixin {
  final MapController _map = MapController();
  bool _gesturing = false;
  List<RodadaLivePosition> _shown = const [];
  List<RodadaLivePosition>? _pending;
  bool _didCenter = false;
  final _offRoute = OffRouteTracker();
  bool _showOffRoute = false;

  List<LatLng> get _corridor {
    final pins = rodadaItineraryLine(
      start: widget.meetup,
      stops: [
        for (final s in widget.stops) LatLng(s.latitude, s.longitude),
      ],
      finish: widget.finish,
    );
    return rodadaDisplayLine(pins: pins, routed: widget.routedLine);
  }

  @override
  void initState() {
    super.initState();
    _shown = widget.positions;
    liveGpsListenable.addListener(_onGps);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCenterOnce();
      startLiveGps(map: _map, centerOnce: false);
    });
  }

  @override
  void dispose() {
    liveGpsListenable.removeListener(_onGps);
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  void _onGps() {
    final p = liveGps;
    final line = _corridor;
    if (p == null || line.length < 2) {
      if (_showOffRoute) setState(() => _showOffRoute = false);
      return;
    }
    final d = distanceToPolylineMeters(p, line);
    final off = _offRoute.update(distanceM: d, now: DateTime.now());
    if (off != _showOffRoute && mounted) {
      setState(() => _showOffRoute = off);
    }
  }

  @override
  void didUpdateWidget(covariant _RodadaLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routedLine != widget.routedLine) {
      _offRoute.reset();
      _onGps();
    }
    if (_samePositions(oldWidget.positions, widget.positions) &&
        oldWidget.meetup == widget.meetup &&
        oldWidget.finish == widget.finish &&
        identical(oldWidget.stops, widget.stops) &&
        identical(oldWidget.routedLine, widget.routedLine)) {
      return;
    }
    if (_gesturing) {
      _pending = widget.positions;
    } else {
      setState(() => _shown = widget.positions);
      _maybeCenterOnce();
    }
  }

  bool _samePositions(List<RodadaLivePosition> a, List<RodadaLivePosition> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _maybeCenterOnce() {
    if (_didCenter || _shown.isEmpty) return;
    _didCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = _shown.first;
      _map.move(LatLng(p.latitude, p.longitude), _map.camera.zoom);
    });
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveStart ||
        event is MapEventFlingAnimationStart ||
        event is MapEventDoubleTapZoomStart) {
      _gesturing = true;
      return;
    }
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      _gesturing = false;
      final pending = _pending;
      if (pending != null) {
        _pending = null;
        setState(() => _shown = pending);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetup = widget.meetup;
    final finish = widget.finish;
    final line = _corridor;
    LatLng center = line.isNotEmpty ? line.first : const LatLng(20.67, -103.35);
    if (_shown.isNotEmpty && !_didCenter) {
      center = LatLng(_shown.first.latitude, _shown.first.longitude);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onMapEvent: _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rawthrottle.riderlab',
            ),
            ...rodadaItineraryMapLayers(
              start: meetup,
              finish: finish,
              routedLine:
                  widget.routedLine.length >= 2 ? widget.routedLine : null,
              stops: [
                for (final s in widget.stops)
                  RodadaItineraryStopPin(
                    point: LatLng(s.latitude, s.longitude),
                    title: s.title,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final p in _shown)
                  Marker(
                    point: LatLng(p.latitude, p.longitude),
                    width: 72,
                    height: 56,
                    child: _LiveRiderMarker(position: p),
                  ),
              ],
            ),
            liveGpsMapChild(),
          ],
        ),
        myLocationOverlay(_map),
        if (_showOffRoute)
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Material(
              color: AppTheme.signal.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route, color: AppTheme.mist, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.offRouteBanner,
                        style: GoogleFonts.exo2(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveRiderMarker extends StatelessWidget {
  const _LiveRiderMarker({required this.position});

  final RodadaLivePosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stale = position.isStale();
    final when = _formatLastSeen(context, position.updatedAt);
    final name = position.label.split(' ').first;
    final caption = stale
        ? l10n.liveRiderNoSignal(name, when)
        : l10n.liveRiderLastSeen(name, when);
    final color = stale ? AppTheme.steel : AppTheme.line;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.asphalt.withValues(alpha: stale ? 0.75 : 0.95),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              height: 1.15,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(
          stale ? Icons.location_off : Icons.navigation,
          color: color,
          size: 22,
        ),
      ],
    );
  }
}

String _formatLastSeen(BuildContext context, DateTime updatedAt) {
  final local = updatedAt.toLocal();
  final now = DateTime.now();
  final delta = now.difference(local);
  final l10n = context.l10n;
  if (delta.inSeconds < 90) return l10n.liveSeenJustNow;
  if (delta.inMinutes < 60) {
    return l10n.liveSeenMinutesAgo(delta.inMinutes.clamp(1, 59));
  }
  return DateFormat.Hm().format(local);
}
