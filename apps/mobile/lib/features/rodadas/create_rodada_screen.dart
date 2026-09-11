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
import '../../providers/rodada_share_prefs.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';
import 'rodada_itinerary.dart';
import 'rodada_itinerary_map.dart';
import 'invite_push_feedback.dart';
import 'rodada_providers.dart';
import 'rodada_repository.dart';
import 'route_prefs_chips.dart';
import '../../widgets/app_snack.dart';

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

  String? _startTitle;
  String? _finishTitle;
  bool _titleLocked = false;
  bool _roundTrip = false;
  bool _missingStart = false;
  bool _missingFinish = false;
  bool _missingTitle = false;
  final _formScroll = ScrollController();
  final _startFieldKey = GlobalKey();
  final _finishFieldKey = GlobalKey();
  final _titleFieldKey = GlobalKey();

  List<LatLng> get _pins => rodadaRouteWaypoints(
    start: _start,
    stops: [for (final s in _stops) s.point],
    finish: _finish,
    roundTrip: _roundTrip,
  );

  List<LatLng> get _displayLine =>
      rodadaDisplayLine(pins: _pins, routed: _route?.points);

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _searchDebounce?.cancel();
    _formScroll.dispose();
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

  List<String> get _genericPlaceNames {
    final l10n = context.l10n;
    return [l10n.rodadaMapPoint, l10n.rodadaMyLocation];
  }

  bool _needsPlaceLookup(String? title) {
    return rodadaTitlePlaceLabel(title, generic: _genericPlaceNames).isEmpty;
  }

  void _place(LatLng point, {String? title}) {
    final l10n = context.l10n;
    final lookup = _needsPlaceLookup(title);
    final label = lookup ? l10n.rodadaMapPoint : title!.trim();
    final modePlaced = _mode;
    setState(() {
      _hits = [];
      switch (_mode) {
        case RodadaPinMode.start:
          _start = point;
          _startTitle = label;
          _missingStart = false;
          _mode = RodadaPinMode.finish;
        case RodadaPinMode.finish:
          _finish = point;
          _finishTitle = label;
          _missingFinish = false;
          _mode = RodadaPinMode.stop;
        case RodadaPinMode.stop:
          _stops.add(
            DraftRodadaStop(
              point: point,
              title: lookup
                  ? l10n.rodadaStopN(_stops.length + 1)
                  : title!.trim(),
            ),
          );
      }
      _syncAutoTitle();
    });
    // Search / GPS picks may be off-screen. A map tap is already under the
    // finger — moving the camera here fights the next pan and freezes flutter_map.
    if (title != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
        } catch (_) {}
      });
    }
    _scheduleRoute();
    if (lookup) {
      unawaited(_resolvePlaceName(point, modePlaced));
    }
  }

  Future<void> _resolvePlaceName(LatLng point, RodadaPinMode mode) async {
    final hit = await ref.read(placeSearchServiceProvider).reverse(point);
    if (!mounted || hit == null || hit.title.trim().isEmpty) return;
    setState(() {
      switch (mode) {
        case RodadaPinMode.start:
          if (_start == point) _startTitle = hit.title;
        case RodadaPinMode.finish:
          if (_finish == point) _finishTitle = hit.title;
        case RodadaPinMode.stop:
          final i = _stops.indexWhere((s) => s.point == point);
          if (i >= 0) {
            _stops[i] = DraftRodadaStop(point: point, title: hit.title);
          }
      }
      _syncAutoTitle();
    });
  }

  void _syncAutoTitle() {
    if (_titleLocked) return;
    _title.text = rodadaAutoTitle(
      startName: rodadaTitlePlaceLabel(
        _startTitle,
        generic: _genericPlaceNames,
      ),
      finishName: rodadaTitlePlaceLabel(
        _finishTitle,
        generic: _genericPlaceNames,
      ),
    );
    final dest = rodadaTitlePlaceLabel(
      _finishTitle,
      generic: _genericPlaceNames,
    );
    _destination.text = dest;
    if (_title.text.trim().isNotEmpty) _missingTitle = false;
  }

  void _scheduleRoute() {
    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(milliseconds: 500), _fetchRoute);
  }

  Future<void> _fetchRoute() async {
    final pins = _pins;
    if (pins.length < 2) {
      if (!mounted) return;
      if (_route == null && !_routing && !_routeFailed) return;
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
    final result = await ref
        .read(directionsServiceProvider)
        .route(waypoints: pins, prefs: _prefs);
    if (!mounted || gen != _routeGen) return;
    setState(() {
      _routing = false;
      _route = result;
      _routeFailed = result == null;
    });
    final points = result?.points;
    if (points == null || points.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _routeGen) return;
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
    });
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
    final hits = await ref
        .read(placeSearchServiceProvider)
        .search(q, viewBounds: bounds, limit: 10);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _hits = hits;
    });
    _fitSearchHits(hits);
  }

  void _fitSearchHits(List<PlaceSearchHit> hits) {
    if (hits.isEmpty) return;
    try {
      final pts = <LatLng>[
        for (final h in hits) h.point,
        if (_start != null) _start!,
        if (_finish != null) _finish!,
        for (final s in _stops) s.point,
      ];
      final bounds = rodadaItineraryBounds(pts);
      if (bounds == null) return;
      _map.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48),
          maxZoom: 15,
        ),
      );
    } catch (_) {}
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
      _place(LatLng(pos.latitude, pos.longitude), title: l10n.rodadaMyLocation);
    } catch (e) {
      if (!mounted) return;
      showAppSnackError(context, l10n.locationFailed('$e'));
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!_titleLocked) _syncAutoTitle();
    final title = _title.text.trim();
    final gaps = rodadaCreateGaps(
      hasStart: _start != null,
      hasFinish: _finish != null,
      title: title,
    );
    if (gaps.any) {
      setState(() {
        _saving = false;
        _error = null;
        _missingStart = gaps.start;
        _missingFinish = gaps.finish;
        _missingTitle = gaps.title;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = gaps.start
            ? _startFieldKey
            : gaps.finish
            ? _finishFieldKey
            : _titleFieldKey;
        final ctx = target.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.15,
            duration: const Duration(milliseconds: 280),
          );
        }
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _missingStart = false;
      _missingFinish = false;
      _missingTitle = false;
    });
    _routeDebounce?.cancel();
    if (_pins.length >= 2 && _route == null && !_routeFailed) {
      await _fetchRoute();
    }
    try {
      final repo = ref.read(rodadaRepositoryProvider);
      final destLabel = rodadaTitlePlaceLabel(
        _finishTitle,
        generic: _genericPlaceNames,
      );
      final dest = _destination.text.trim().isNotEmpty
          ? _destination.text.trim()
          : destLabel;
      final rodada = await repo.createRodada(
        title: title,
        destination: dest.isEmpty ? null : dest,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        meetupLat: _start?.latitude,
        meetupLng: _start?.longitude,
        finishLat: _finish?.latitude,
        finishLng: _finish?.longitude,
        startsAt: _startsAt,
        route: _route,
        prefs: _prefs,
      );
      await applyShareSettingsToMembership(
        repo: repo,
        rodadaId: rodada.id,
        settings: ref.read(rodadaSharePrefsProvider),
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
      final inviteResults = <RodadaInviteResult>[];
      for (final id in _inviteIds) {
        inviteResults.add(
          await repo.inviteUser(rodadaId: rodada.id, userId: id),
        );
      }
      if (!mounted) return;
      final pushMsg = messageForInviteBatch(l10n, inviteResults);
      Navigator.of(context).pop(rodada.id);
      if (pushMsg != null) {
        showAppSnack(null, pushMsg);
      }
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

  String _modePrompt(AppLocalizations l10n) {
    return switch (_mode) {
      RodadaPinMode.start => l10n.rodadaAskStart,
      RodadaPinMode.finish => l10n.rodadaAskFinish,
      RodadaPinMode.stop => l10n.rodadaAskStops,
    };
  }

  String _searchHint(AppLocalizations l10n) {
    return switch (_mode) {
      RodadaPinMode.start => l10n.rodadaSearchStartHint,
      RodadaPinMode.finish => l10n.rodadaSearchFinishHint,
      RodadaPinMode.stop => l10n.rodadaSearchStopHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final line = _displayLine;
    final friendsAsync = ref.watch(friendsListProvider);
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _modePrompt(l10n),
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.rodadaItineraryHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
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
                    setState(() {
                      _mode = set.first;
                      _hits = [];
                      _search.clear();
                    });
                  },
                ),
                const SizedBox(height: 8),
                ListenableBuilder(
                  listenable: _search,
                  builder: (context, _) {
                    return TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: _searchHint(l10n),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                      onChanged: _onSearchChanged,
                    );
                  },
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
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _CreateRodadaMap(
                  map: _map,
                  line: line,
                  start: _start,
                  finish: _finish,
                  stops: _stops,
                  routedLine: _route?.points,
                  hits: _hits,
                  liveGps: liveGpsMapChild(),
                  locationOverlay: myLocationOverlay(_map),
                  onTap: _place,
                  onSelectHit: _pickHit,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              controller: _formScroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (_hits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _hits.length; i++)
                        ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: const Color(0xFF7C9CFF),
                            foregroundColor: AppTheme.asphalt,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          label: Text(
                            _hits[i].title,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () => _pickHit(_hits[i]),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                if (_routing)
                  Text(
                    l10n.routeRouting,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 13,
                    ),
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
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.signal,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 8),
                RoutePrefsChips(
                  prefs: _prefs,
                  onChanged: (next) {
                    setState(() => _prefs = next);
                    _scheduleRoute();
                  },
                ),
                if (_start != null && _finish != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.rodadaRoundTrip),
                    subtitle: Text(
                      l10n.rodadaRoundTripHelp,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 13,
                      ),
                    ),
                    value: _roundTrip,
                    onChanged: (v) {
                      setState(() => _roundTrip = v);
                      _scheduleRoute();
                    },
                  ),
                _PinRow(
                  key: _startFieldKey,
                  icon: Icons.flag,
                  color: AppTheme.lineHot,
                  label: '${l10n.rodadaPinStart} *',
                  value: _start == null ? l10n.rodadaPinUnset : _startTitle,
                  errorText: _missingStart ? l10n.rodadaStartRequired : null,
                  onClear: _start == null
                      ? null
                      : () {
                          setState(() {
                            _start = null;
                            _startTitle = null;
                            _mode = RodadaPinMode.start;
                            _syncAutoTitle();
                          });
                          _scheduleRoute();
                        },
                ),
                _PinRow(
                  key: _finishFieldKey,
                  icon: Icons.sports_score,
                  color: AppTheme.line,
                  label: '${l10n.rodadaPinFinish} *',
                  value: _finish == null ? l10n.rodadaPinUnset : _finishTitle,
                  errorText: _missingFinish ? l10n.rodadaFinishRequired : null,
                  onClear: _finish == null
                      ? null
                      : () {
                          setState(() {
                            _finish = null;
                            _finishTitle = null;
                            _mode = RodadaPinMode.finish;
                            _syncAutoTitle();
                          });
                          _scheduleRoute();
                        },
                ),
                for (var i = 0; i < _stops.length; i++)
                  _PinRow(
                    icon: Icons.local_gas_station,
                    color: AppTheme.signal,
                    label: '${rodadaStopLetter(i)} · ${_stops[i].title}',
                    onClear: () {
                      setState(() => _stops.removeAt(i));
                      _scheduleRoute();
                    },
                  ),
                const SizedBox(height: 16),
                TextField(
                  key: _titleFieldKey,
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: '${l10n.rodadaTitleLabel} *',
                    hintText: l10n.rodadaTitleHint,
                    errorText: _missingTitle ? l10n.titleRequired : null,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) {
                    _titleLocked = v.trim().isNotEmpty;
                    if (_missingTitle && v.trim().isNotEmpty) {
                      setState(() => _missingTitle = false);
                    }
                  },
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
          ),
        ],
      ),
    );
  }
}

/// Own [State] so form `setState` updates markers without remounting tiles.
class _CreateRodadaMap extends StatefulWidget {
  const _CreateRodadaMap({
    required this.map,
    required this.line,
    required this.start,
    required this.finish,
    required this.stops,
    required this.routedLine,
    required this.hits,
    required this.liveGps,
    required this.locationOverlay,
    required this.onTap,
    required this.onSelectHit,
  });

  final MapController map;
  final List<LatLng> line;
  final LatLng? start;
  final LatLng? finish;
  final List<DraftRodadaStop> stops;
  final List<LatLng>? routedLine;
  final List<PlaceSearchHit> hits;
  final Widget liveGps;
  final Widget locationOverlay;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<PlaceSearchHit> onSelectHit;

  @override
  State<_CreateRodadaMap> createState() => _CreateRodadaMapState();
}

class _CreateRodadaMapState extends State<_CreateRodadaMap> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.map,
          options: MapOptions(
            initialCenter: widget.line.isNotEmpty
                ? widget.line.first
                : const LatLng(20.67, -103.35),
            initialZoom: widget.line.isEmpty ? 10 : 14,
            onTap: (_, p) => widget.onTap(p),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rawthrottle.riderlab',
            ),
            ...rodadaItineraryMapLayers(
              start: widget.start,
              finish: widget.finish,
              routedLine: widget.routedLine,
              stops: [
                for (final s in widget.stops)
                  RodadaItineraryStopPin(point: s.point, title: s.title),
              ],
            ),
            if (widget.hits.isNotEmpty)
              MarkerLayer(
                markers: rodadaSearchHitMarkers(
                  points: [for (final h in widget.hits) h.point],
                  titles: [for (final h in widget.hits) h.title],
                  onSelect: (i) => widget.onSelectHit(widget.hits[i]),
                ),
              ),
            widget.liveGps,
          ],
        ),
        widget.locationOverlay,
      ],
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.errorText,
    this.onClear,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final String? errorText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missing = errorText != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: missing ? Border.all(color: AppTheme.signal) : null,
        color: missing ? AppTheme.signal.withValues(alpha: 0.08) : null,
      ),
      child: ListTile(
        contentPadding: missing
            ? const EdgeInsets.fromLTRB(8, 0, 8, 0)
            : EdgeInsets.zero,
        leading: Icon(icon, color: missing ? AppTheme.signal : color),
        title: Text(label),
        subtitle: missing
            ? Text(errorText!, style: const TextStyle(color: AppTheme.signal))
            : (value == null || value!.isEmpty ? null : Text(value!)),
        trailing: onClear == null
            ? null
            : TextButton(onPressed: onClear, child: Text(l10n.clearPin)),
      ),
    );
  }
}
