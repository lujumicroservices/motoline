import 'dart:async';

import '../db/ride_database.dart';
import '../models/route_circuit.dart';
import 'loop_lap_detector.dart';
import 'ride_recorder.dart';
import 'route_service.dart';

/// Default corridor radius (meters) around the loop-init point used for
/// auto-lap geofence detection. See docs/REQUIREMENTS.md §3.
const double kLoopGeofenceRadiusMeters = 50;

/// Minimum distance (meters) a lap must cover before an init-zone re-entry
/// counts as a completed lap (guards against noise right at the line).
const double kLoopMinLapDistanceMeters = 200;

/// Minimum time a lap must take before a re-entry counts as completed.
const Duration kLoopMinLapDuration = Duration(seconds: 30);

/// Immutable snapshot of Loop mode session state for the UI.
class LoopSessionState {
  const LoopSessionState({
    this.route,
    this.lapCount = 0,
    this.armed = false,
    this.ended = false,
  });

  final RouteCircuit? route;
  final int lapCount;
  final bool armed;
  final bool ended;

  bool get hasInit => route?.hasLoopInit ?? false;
  bool get hasEnd => route?.hasLoopEnd ?? false;

  LoopSessionState copyWith({
    RouteCircuit? route,
    int? lapCount,
    bool? armed,
    bool? ended,
  }) =>
      LoopSessionState(
        route: route ?? this.route,
        lapCount: lapCount ?? this.lapCount,
        armed: armed ?? this.armed,
        ended: ended ?? this.ended,
      );
}

/// Drives the Loop mode flow on top of an already-recording [RideRecorder]:
/// mark init/end, arm auto-lap detection, and roll one Ride per lap while
/// tagging every lap with the same [RouteCircuit.id].
class LoopSessionController {
  LoopSessionController({
    required RideRecorder recorder,
    RideDatabase? database,
    RouteService? routeService,
  })  : _recorder = recorder,
        _db = database ?? RideDatabase.instance,
        _routeService = routeService ?? RouteService(database: database);

  final RideRecorder _recorder;
  final RideDatabase _db;
  final RouteService _routeService;

  late final StreamController<LoopSessionState> _stateController =
      StreamController<LoopSessionState>.broadcast(
    onListen: () => _stateController.add(_snapshot),
  );
  StreamSubscription<ActiveRideSnapshot>? _lapSub;

  RouteCircuit? _route;
  LoopLapDetector? _lapDetector;
  int _lapCount = 0;
  bool _busy = false;
  bool _ended = false;

  Stream<LoopSessionState> get states => _stateController.stream;

  LoopSessionState get _snapshot => LoopSessionState(
        route: _route,
        lapCount: _lapCount,
        armed: _lapDetector != null,
        ended: _ended,
      );

  void _emit() => _stateController.add(_snapshot);

  /// Marks the loop-init point (A). Uses [lat]/[lng] when provided; otherwise
  /// the rider's current live GPS fix.
  Future<void> markInit({
    String? routeName,
    double? lat,
    double? lng,
  }) async {
    final live = _recorder.lastLivePoint;
    final latitude = lat ?? live?.latitude;
    final longitude = lng ?? live?.longitude;
    if (latitude == null || longitude == null) return;

    var route = _route;
    if (route == null) {
      final created = await _routeService.createRoute(
        name: routeName ?? _autoRouteName(),
        isShared: true,
      );
      route = created;
    }

    route = route.copyWith(initLat: latitude, initLng: longitude);
    await _db.upsertRoute(route);
    _route = route;

    await _recorder.setActiveRideRouteId(route.id);
    _emit();
  }

  /// Marks the loop-end point (B) and arms auto-lap detection. Requires
  /// [markInit] first. Uses [lat]/[lng] when provided; otherwise live GPS.
  Future<void> markEnd({double? lat, double? lng}) async {
    final route = _route;
    final live = _recorder.lastLivePoint;
    final latitude = lat ?? live?.latitude;
    final longitude = lng ?? live?.longitude;
    if (route == null || !route.hasLoopInit || latitude == null || longitude == null) {
      return;
    }

    final updated = route.copyWith(
      endLat: latitude,
      endLng: longitude,
      geofenceRadiusM: kLoopGeofenceRadiusMeters,
    );
    await _db.upsertRoute(updated);
    _route = updated;

    _lapDetector = LoopLapDetector(
      initLat: updated.initLat!,
      initLng: updated.initLng!,
      geofenceRadiusM: updated.geofenceRadiusM!,
      minLapDistanceMeters: kLoopMinLapDistanceMeters,
      minLapDuration: kLoopMinLapDuration,
    )..startLap(DateTime.now());

    _lapSub ??= _recorder.snapshots.listen(_onSnapshot);
    _emit();
  }

  void _onSnapshot(ActiveRideSnapshot snap) {
    if (_busy || _ended) return;
    final detector = _lapDetector;
    final last = snap.lastPoint;
    if (detector == null || last == null) return;
    // Auto-pause already stops distance/points; skip lap math while paused.
    if (snap.isPaused) return;

    final completed = detector.feed(
      lat: last.latitude,
      lng: last.longitude,
      timestamp: last.timestamp,
    );
    if (completed) {
      unawaited(_completeLapAndRoll());
    }
  }

  Future<void> _completeLapAndRoll() async {
    if (_busy) return;
    _busy = true;
    try {
      final route = _route;
      if (route == null || !_recorder.isRecording) return;

      await _recorder.stop();
      _lapCount++;
      _emit();

      // Seamless roll: GPS stream is already warm, skip the warmup UI.
      await _recorder.start(skipWarmup: true, routeId: route.id);
      _lapDetector?.startLap(DateTime.now());
      _emit();
    } finally {
      _busy = false;
    }
  }

  /// Stops the current lap (if recording) and disarms Loop mode.
  Future<void> endSession() async {
    _ended = true;
    await _lapSub?.cancel();
    _lapSub = null;
    _lapDetector = null;
    if (_recorder.isRecording) {
      await _recorder.stop();
    }
    _emit();
  }

  String _autoRouteName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Loop ${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  Future<void> dispose() async {
    await _lapSub?.cancel();
    await _stateController.close();
  }
}
