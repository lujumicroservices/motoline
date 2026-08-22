import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/routing/route_prefs.dart';
import '../../core/services/directions_service.dart';
import '../../core/services/place_search_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';
import 'rodada_itinerary.dart';
import 'rodada_itinerary_map.dart';
import 'rodada_providers.dart';
import 'route_prefs_chips.dart';

class CreateRodadaScreen extends ConsumerStatefulWidget {
  const CreateRodadaScreen({super.key});

  @override
  ConsumerState<CreateRodadaScreen> createState() => _CreateRodadaScreenState();
}

class _CreateRodadaScreenState extends ConsumerState<CreateRodadaScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  final _title = TextEditingController();
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  final _search = TextEditingController();
  DateTime? _startsAt;
  RodadaPinMode _mode = RodadaPinMode.start;
  LatLng? _start;
  LatLng? _finish;
  final List<DraftRodadaStop> _stops = [];
  bool _saving = false;
  String? _error;
  RoutePrefs _prefs = RoutePrefs.defaults;
  DirectionsResult? _route;
  bool _routing = false;
  bool _routeFailed = false;
  int _routeGen = 0;
  Timer? _routeDebounce;
  Timer? _searchDebounce;
  List<PlaceSearchHit> _hits = [];
  bool _searching = false;
  final Set<String> _inviteIds = {};

  List<LatLng> get _pins => rodadaItineraryLine(
        start: _start,
        stops: [for (final s in _stops) s.point],
        finish: _finish,
      );

  List<LatLng> get _displayLine =>
      rodadaDisplayLine(pins: _pins, routed: _route?.points);

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _searchDebounce?.cancel();
    stopLiveGps();
    disposeLiveGpsListenable();
    _title.dispose();
    _destination.dispose();
    _notes.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _place(LatLng point, {String? title}) {
    final l10n = context.l10n;
    setState(() {
      switch (_mode) {
        case RodadaPinMode.start:
          _start = point;
        case RodadaPinMode.finish:
          _finish = point;
        case RodadaPinMode.stop:
          _stops.add(
            DraftRodadaStop(
              point: point,
              title: (title != null && title.trim().isNotEmpty)
                  ? title.trim()
                  : l10n.rodadaStopN(_stops.length + 1),
            ),
          );
      }
    });
    try {
      _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
    } catch (_) {}
    _scheduleRoute();
  }

  void _scheduleRoute() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 500), _fetchRoute);
  }

  Future<void> _fetchRoute() async {
    final pins = _pins;
    if (pins.length < 2) {
      if (!mounted) return;
      setState(() {
        _route = null;
        _routeFailed = false;
        _routing = false;
      });
      return;
    }
    final gen = ++_routeGen;
    setState(() {
      _routing = true;
      _routeFailed = false;
    });
    final result = await ref.read(directionsServiceProvider).route(
          waypoints: pins,
          prefs: _prefs,
        );
    if (!mounted || gen != _routeGen) return;
    setState(() {
      _routing = false;
      _route = result;
      _routeFailed = result == null;
    });
    final points = result?.points;
    if (points == null || points.length < 2) return;
    try {
      final bounds = rodadaItineraryBounds(points);
      if (bounds != null) {
        _map.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(28),
            maxZoom: 14,
          ),
        );
      }
    } catch (_) {}
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _hits = [];
        _searching = false;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(q),
    );
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    LatLngBounds? bounds;
    try {
      bounds = _map.camera.visibleBounds;
    } catch (_) {}
    final hits = await ref.read(placeSearchServiceProvider).search(
          q,
          viewBounds: bounds,
          limit: 10,
        );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _hits = hits;
    });
  }

  void _pickHit(PlaceSearchHit hit) {
    _search.clear();
    setState(() => _hits = []);
    _place(hit.point, title: hit.title);
  }

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      _place(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationFailed('$e'))),
      );
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.titleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    _routeDebounce?.cancel();
    if (_pins.length >= 2 && _route == null && !_routeFailed) {
      await _fetchRoute();
    }
    try {
      final repo = ref.read(rodadaRepositoryProvider);
      final rodada = await repo.createRodada(
        title: title,
        destination: _destination.text.trim().isEmpty
            ? null
            : _destination.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        meetupLat: _start?.latitude,
        meetupLng: _start?.longitude,
        finishLat: _finish?.latitude,
        finishLng: _finish?.longitude,
        startsAt: _startsAt,
        route: _route,
        prefs: _prefs,
      );
      for (var i = 0; i < _stops.length; i++) {
        final stop = _stops[i];
        await repo.addStop(
          rodadaId: rodada.id,
          title: stop.title,
          latitude: stop.point.latitude,
          longitude: stop.point.longitude,
          sortOrder: i,
        );
      }
      for (final id in _inviteIds) {
        await repo.inviteUser(rodadaId: rodada.id, userId: id);
      }
      if (!mounted) return;
      Navigator.of(context).pop(rodada.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  String _modeLabel(AppLocalizations l10n, RodadaPinMode mode) {
    return switch (mode) {
      RodadaPinMode.start => l10n.rodadaPinStart,
      RodadaPinMode.finish => l10n.rodadaPinFinish,
      RodadaPinMode.stop => l10n.rodadaPinStop,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final line = _displayLine;
    final friendsAsync = ref.watch(friendsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.newRodada,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.rodadaCreateButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.rodadaTitleLabel,
              hintText: l10n.rodadaTitleHint,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            decoration: InputDecoration(
              labelText: l10n.rodadaDestinationLabel,
              hintText: l10n.rodadaDestinationHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.rodadaNotesLabel,
              hintText: l10n.rodadaNotesHint,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.rodadaStartsAt),
            subtitle: Text(
              _startsAt == null
                  ? l10n.rodadaPickDateTime
                  : _startsAt!.toLocal().toString().substring(0, 16),
            ),
            trailing: const Icon(Icons.schedule),
            onTap: _pickStartsAt,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rodadaItinerary,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RoutePrefsChips(
            prefs: _prefs,
            onChanged: (next) {
              setState(() => _prefs = next);
              _scheduleRoute();
            },
          ),
          const SizedBox(height: 8),
          if (_routing)
            Text(
              l10n.routeRouting,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
            )
          else if (_route != null)
            Text(
              l10n.routeSummaryKmEta(
                formatRouteDistance(_route!.distanceM),
                formatRouteEta(_route!.durationS),
              ),
              style: GoogleFonts.rajdhani(
                color: AppTheme.mist,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (_routeFailed)
            Text(
              l10n.routeFailedFallback,
              style: GoogleFonts.rajdhani(color: AppTheme.signal, fontSize: 13),
            ),
          const SizedBox(height: 8),
          SegmentedButton<RodadaPinMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in RodadaPinMode.values)
                ButtonSegment(
                  value: mode,
                  label: Text(_modeLabel(l10n, mode)),
                ),
            ],
            selected: {_mode},
            onSelectionChanged: (set) {
              if (set.isEmpty) return;
              setState(() => _mode = set.first);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: l10n.routeSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_search.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _hits = []);
                          },
                        )),
            ),
            textInputAction: TextInputAction.search,
            onChanged: (q) {
              setState(() {});
              _onSearchChanged(q);
            },
          ),
          if (_hits.isNotEmpty)
            Card(
              color: AppTheme.asphaltElevated,
              child: Column(
                children: [
                  for (final hit in _hits)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, color: AppTheme.line),
                      title: Text(hit.title),
                      subtitle: hit.subtitle == null ? null : Text(hit.subtitle!),
                      onTap: () => _pickHit(hit),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: _useMyLocation,
                child: Text(l10n.useMyGps),
              ),
            ],
          ),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: line.isNotEmpty
                          ? line.first
                          : const LatLng(20.67, -103.35),
                      initialZoom: line.isEmpty ? 10 : 14,
                      onTap: (_, p) => _place(p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rawthrottle.riderlab',
                      ),
                      ...rodadaItineraryMapLayers(
                        start: _start,
                        finish: _finish,
                        routedLine: _route?.points,
                        stops: [
                          for (final s in _stops)
                            RodadaItineraryStopPin(
                              point: s.point,
                              title: s.title,
                            ),
                        ],
                      ),
                      if (_hits.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            for (final hit in _hits)
                              Marker(
                                point: hit.point,
                                width: 40,
                                height: 40,
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _pickHit(hit),
                                  child: Tooltip(
                                    message: hit.title,
                                    child: const Icon(
                                      Icons.place,
                                      color: Color(0xFF7C9CFF),
                                      size: 34,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      liveGpsMapChild(),
                    ],
                  ),
                  myLocationOverlay(_map),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rodadaItineraryHelp,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _PinRow(
            icon: Icons.flag,
            color: AppTheme.lineHot,
            label: l10n.rodadaPinStart,
            value: _start == null ? l10n.rodadaPinUnset : null,
            onClear: _start == null
                ? null
                : () {
                    setState(() => _start = null);
                    _scheduleRoute();
                  },
          ),
          _PinRow(
            icon: Icons.sports_score,
            color: AppTheme.line,
            label: l10n.rodadaPinFinish,
            value: _finish == null ? l10n.rodadaPinUnset : null,
            onClear: _finish == null
                ? null
                : () {
                    setState(() => _finish = null);
                    _scheduleRoute();
                  },
          ),
          for (var i = 0; i < _stops.length; i++)
            _PinRow(
              icon: Icons.local_gas_station,
              color: AppTheme.signal,
              label: _stops[i].title,
              onClear: () {
                setState(() => _stops.removeAt(i));
                _scheduleRoute();
              },
            ),
          const SizedBox(height: 16),
          Text(
            l10n.inviteFriends,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          friendsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (friends) {
              if (friends.isEmpty) {
                return Text(
                  l10n.noFriendsToInvite,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                children: [
                  for (final f in friends)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _inviteIds.contains(f.id),
                      title: Text(f.label),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _inviteIds.add(f.id);
                          } else {
                            _inviteIds.remove(f.id);
                          }
                        });
                      },
                    ),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.signal)),
          ],
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.onClear,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: value == null ? null : Text(value!),
      trailing: onClear == null
          ? null
          : TextButton(
              onPressed: onClear,
              child: Text(l10n.clearPin),
            ),
    );
  }
}
