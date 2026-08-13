import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'arm_foreground_service.dart';
import 'barometer_sensor.dart';
import '../lean_lab/lean_imu_math.dart';
import 'lean_sensor.dart';
import 'location_service.dart';
import 'motion_pattern_detector.dart';
import 'ride_place_name_service.dart';
import 'rider_telemetry_service.dart';

class ActiveRideSnapshot {
  const ActiveRideSnapshot({
    required this.ride,
    required this.points,
    required this.lastPoint,
    this.relativeLeanDegrees,
    this.maxLeanLeftDegrees,
    this.maxLeanRightDegrees,
    this.leanCalibrated = false,
    this.isPaused = false,
    this.suggestEnd = false,
    this.pausedFor,
    this.autoPauseEnabled = true,
    this.gpsRateHz,
    this.pressureHpa,
  });

  final Ride ride;
  final List<TrackPoint> points;
  final TrackPoint? lastPoint;
  final double? relativeLeanDegrees;
  final double? maxLeanLeftDegrees;
  final double? maxLeanRightDegrees;
  final bool leanCalibrated;

  /// True while auto-paused (low speed sustained) — points aren't stored.
  final bool isPaused;

  /// True once near-stationary for long enough that the UI should offer
  /// "End ride?" — cleared automatically when motion resumes.
  final bool suggestEnd;

  /// How long the ride has been auto-paused, when [isPaused] is true.
  final Duration? pausedFor;

  /// Whether automatic pause/resume is armed for this session.
  final bool autoPauseEnabled;

  /// Rolling accepted-fix rate over ~12 s (null until enough samples).
  final double? gpsRateHz;

  /// Latest barometer reading (hPa), when the phone has one.
  final double? pressureHpa;
}

/// Offline-first recorder: GPS + lean IMU, flushed to SQLite in batches.
///
/// Also owns the "arm for auto-start" flow: while armed (and not already
/// recording), a light GPS stream watches for a motion pattern that looks
/// like the start of a ride, then calls [start] automatically and emits on
/// [autoStartEvents] so the UI can navigate to the active ride screen.
class RideRecorder {
  RideRecorder({
    RideDatabase? database,
    LocationService? locationService,
    LeanSensor? leanSensor,
    BarometerSensor? barometerSensor,
  })  : _db = database ?? RideDatabase.instance,
        _location = locationService ?? LocationService(),
        _lean = leanSensor ?? LeanSensor(),
        _baro = barometerSensor ?? BarometerSensor();

  final RideDatabase _db;
  final LocationService _location;
  final LeanSensor _lean;
  final BarometerSensor _baro;
  final _uuid = const Uuid();

  final _pending = <TrackPoint>[];
  final _controller = StreamController<ActiveRideSnapshot>.broadcast();
  final _autoStartController = StreamController<Ride>.broadcast();
  final _fixAcceptTimes = <DateTime>[];
  final _armedController = StreamController<bool>.broadcast();

  final MotionPatternDetector _motion = MotionPatternDetector();
  final MotionPatternDetector _armMotion = MotionPatternDetector();
  final RiderTelemetryService _telemetry = RiderTelemetryService.instance;

  StreamSubscription<Position>? _sub;
  StreamSubscription<Position>? _armSub;
  Timer? _flushTimer;
  Ride? _ride;
  bool _wasPaused = false;
  bool _wasSuggestEnd = false;
  int _gpsSkipAccuracy = 0;
  int _gpsSkipTeleport = 0;

  /// Last accepted GPS fix, updated even while auto-paused (for live UI).
  TrackPoint? _lastPoint;

  /// Last fix that was actually stored on the path (used for jump/distance
  /// checks); frozen while auto-paused so the map shows a natural gap.
  TrackPoint? _lastStoredPoint;

  final List<TrackPoint> _sessionPoints = [];
  double _distanceMeters = 0;
  double? _maxSpeedMps;
  double _speedSum = 0;
  int _speedSamples = 0;
  double? _maxLeanAbs;
  double _maxLeanLeft = 0;
  double _maxLeanRight = 0;
  bool _armed = false;
  String? _armedRouteId;
  bool _promotingArm = false;
  bool _autoPauseEnabled = true;
  bool _autoPausePrefLoaded = false;
  double? _pendingLeanNeutral;
  Vec3? _pendingG0;
  int _pendingSignFlip = 1;

  static const _autoPausePrefKey = 'corneriq_auto_pause';
  static const preferredArmRoutePrefKey = 'corneriq_arm_route_id';

  Stream<ActiveRideSnapshot> get snapshots => _controller.stream;

  /// Fires with the newly created ride whenever arm+auto-start fires.
  Stream<Ride> get autoStartEvents => _autoStartController.stream;

  /// Fires whenever the armed state changes (true = armed, waiting for motion).
  Stream<bool> get armedStates => _armedController.stream;

  Ride? get activeRide => _ride;
  bool get isRecording => _ride?.status == RideStatus.recording;
  bool get isArmed => _armed;
  /// Route id that will be applied when arm auto-starts (if any).
  String? get armedRouteId => _armedRouteId;
  bool get isPaused => isRecording && _motion.isPaused;

  /// Automatic pause/resume while recording (persisted).
  bool get autoPauseEnabled => _autoPauseEnabled;

  Future<void> setAutoPauseEnabled(bool enabled) async {
    await _ensureAutoPausePref();
    if (_autoPauseEnabled == enabled) return;
    _autoPauseEnabled = enabled;
    _motion.autoPauseEnabled = enabled;
    if (!enabled) {
      _motion.clearPause();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPausePrefKey, enabled);
    if (isRecording) _emit();
  }

  /// Queue a Lean Lab frozen neutral to apply right after [start].
  void prepareLeanLabNeutral(double degrees) {
    _pendingLeanNeutral = degrees;
  }

  /// Queue frozen upright gravity (and optional screen-in sign flip).
  void prepareLeanLabUpright(Vec3 g0, {int signFlip = 1}) {
    _pendingG0 = g0;
    _pendingSignFlip = signFlip;
  }

  /// Lock lean zero during an active recording (Lean Lab).
  void lockLeanNeutral(double degrees) {
    _lean.lockNeutral(degrees);
    _pendingLeanNeutral = null;
  }

  /// Lock frozen g0 during an active recording (Lean Lab).
  void lockLeanUpright(Vec3 g0, {int signFlip = 1}) {
    _lean.lockUpright(g0, signFlip: signFlip);
    _pendingG0 = null;
    _pendingLeanNeutral = 0;
  }

  void _applyPendingLeanLock() {
    final g0 = _pendingG0;
    if (g0 != null) {
      _lean.lockUpright(g0, signFlip: _pendingSignFlip);
      _pendingG0 = null;
      _pendingLeanNeutral = null;
      return;
    }
    final pendingNeutral = _pendingLeanNeutral;
    if (pendingNeutral != null) {
      _lean.lockNeutral(pendingNeutral);
      _pendingLeanNeutral = null;
    }
  }

  double? get leanNeutralDegrees => _lean.neutralDegrees;

  Future<void> _ensureAutoPausePref() async {
    if (_autoPausePrefLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _autoPauseEnabled = prefs.getBool(_autoPausePrefKey) ?? true;
    _motion.autoPauseEnabled = _autoPauseEnabled;
    _autoPausePrefLoaded = true;
  }

  /// Last live GPS fix (updated even while paused) — used by callers (e.g.
  /// Loop mode HUD) that need "current position" without waiting on stored
  /// points.
  TrackPoint? get lastLivePoint => _lastPoint;

  Future<Ride?> recoverIncompleteRide() => _db.getActiveRide();

  Future<Ride> start({
    void Function(GnssWarmupStatus status)? onWarmup,
    bool skipWarmup = false,
    String? routeId,
  }) async {
    if (_ride != null) {
      throw StateError('A ride is already recording');
    }
    // Auto-start and manual start are mutually exclusive.
    disarm();
    await _ensureAutoPausePref();

    unawaited(
      _telemetry.log(
        category: TelemetryCategory.ride,
        eventType: 'start_requested',
        payload: {
          'route_id': routeId,
          'skip_warmup': skipWarmup,
          'auto_pause': _autoPauseEnabled,
        },
      ),
    );

    onWarmup?.call(
      const GnssWarmupStatus(
        phase: GpsWarmupPhase.permissions,
      ),
    );

    final permission = await _location.ensurePermission();
    if (!permission.granted) {
      final reason =
          permission.reason ?? LocationPermissionDenyReason.denied;
      unawaited(
        _telemetry.error(
          where: 'ride.start.permission',
          error: reason.name,
          category: TelemetryCategory.gps,
        ),
      );
      throw LocationDeniedException(reason);
    }

    if (skipWarmup) {
      onWarmup?.call(
        const GnssWarmupStatus(
          phase: GpsWarmupPhase.ready,
        ),
      );
    } else {
      // Lock onto GNSS before the first stored point (shows live accuracy in UI).
      await for (final status in _location.warmUpGnss()) {
        onWarmup?.call(status);
        if (status.phase == GpsWarmupPhase.ready ||
            status.phase == GpsWarmupPhase.timeout) {
          unawaited(
            _telemetry.log(
              category: TelemetryCategory.gps,
              eventType: 'warmup_${status.phase.name}',
              payload: {
                'accuracy_m': status.accuracyMeters,
              },
            ),
          );
        }
      }
    }

    final ride = Ride(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      status: RideStatus.recording,
      routeId: routeId,
    );
    await _db.upsertRide(ride);
    _ride = ride;
    _telemetry.bindRide(ride.id);
    _sessionPoints.clear();
    _pending.clear();
    _lastPoint = null;
    _lastStoredPoint = null;
    _distanceMeters = 0;
    _maxSpeedMps = null;
    _speedSum = 0;
    _speedSamples = 0;
    _maxLeanAbs = null;
    _maxLeanLeft = 0;
    _maxLeanRight = 0;
    _wasPaused = false;
    _wasSuggestEnd = false;
    _gpsSkipAccuracy = 0;
    _gpsSkipTeleport = 0;
    _fixAcceptTimes.clear();
    _motion.resetForNewRide();

    _lean.start();
    _baro.start();
    _applyPendingLeanLock();

    _flushTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _flushPending(),
    );

    _sub = _location.watchPositions().listen(
      _onPosition,
      onError: (Object error, StackTrace stack) {
        unawaited(
          _telemetry.error(
            where: 'ride.gps_stream',
            error: error,
            category: TelemetryCategory.gps,
          ),
        );
      },
    );

    unawaited(
      _telemetry.log(
        category: TelemetryCategory.ride,
        eventType: 'started',
        rideLocalId: ride.id,
        payload: {'route_id': routeId},
      ),
    );

    _emit();
    return ride;
  }

  Future<Ride> stop() async {
    final ride = _ride;
    if (ride == null) {
      throw StateError('No active ride');
    }

    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _lean.stop();
    _baro.stop();
    _fixAcceptTimes.clear();
    unawaited(ArmForegroundService.stop());
    await _flushPending();

    final completed = ride.copyWith(
      endedAt: DateTime.now(),
      status: RideStatus.completed,
      distanceMeters: _distanceMeters,
      pointCount: _sessionPoints.length,
      maxSpeedMps: _maxSpeedMps,
      avgSpeedMps: _speedSamples == 0 ? null : _speedSum / _speedSamples,
      maxLeanDegrees: _maxLeanAbs,
    );
    await _db.upsertRide(completed);
    unawaited(_assignPlaceTitle(completed));
    unawaited(
      _telemetry.log(
        category: TelemetryCategory.ride,
        eventType: 'stopped',
        rideLocalId: completed.id,
        payload: {
          'distance_m': completed.distanceMeters,
          'point_count': completed.pointCount,
          'max_speed_mps': completed.maxSpeedMps,
          'gps_skip_accuracy': _gpsSkipAccuracy,
          'gps_skip_teleport': _gpsSkipTeleport,
          'duration_s': completed.endedAt
              ?.difference(completed.startedAt)
              .inSeconds,
        },
      ),
    );
    unawaited(_telemetry.flushPending());
    _telemetry.bindRide(null);
    _ride = null;
    _emitCompleted(completed);
    return completed;
  }

  /// Best-effort reverse-geocode start/end → `Cañadas - Moyahua`.
  Future<void> _assignPlaceTitle(Ride ride) async {
    try {
      if (ride.title != null && ride.title!.trim().isNotEmpty) return;
      final points = await _db.getPoints(ride.id);
      if (points.isEmpty) return;
      final title = await RidePlaceNameService().titleFromTrack(points);
      if (title == null || title.trim().isEmpty) return;
      final named = ride.copyWith(title: title.trim());
      await _db.upsertRide(named);
      debugPrint('CornerIQ ride title: $title');
    } catch (e) {
      debugPrint('CornerIQ ride title: $e');
    }
  }

  /// Retag the currently-recording ride with [routeId] (e.g. once Loop mode
  /// creates the route after recording has already begun).
  Future<void> setActiveRideRouteId(String routeId) async {
    final ride = _ride;
    if (ride == null) return;
    _ride = ride.copyWith(routeId: routeId);
    await _db.upsertRide(_ride!);
    _emit();
  }

  Future<Ride> finalizeRecovered(String rideId) async {
    final ride = await _db.getRide(rideId);
    if (ride == null) {
      throw StateError('Ride not found');
    }
    final points = await _db.getPoints(rideId);
    final distance = pathDistanceMeters(points);
    double? maxSpeed;
    double? maxLean;
    var speedSum = 0.0;
    var speedSamples = 0;
    for (final p in points) {
      final s = p.speedMps;
      if (s != null && s >= 0) {
        maxSpeed = maxSpeed == null ? s : (s > maxSpeed ? s : maxSpeed);
        speedSum += s;
        speedSamples++;
      }
      final lean = p.absLeanDegrees;
      if (lean != null) {
        maxLean = maxLean == null ? lean : (lean > maxLean ? lean : maxLean);
      }
    }
    final completed = ride.copyWith(
      endedAt: points.isEmpty ? DateTime.now() : points.last.timestamp,
      status: RideStatus.completed,
      distanceMeters: distance,
      pointCount: points.length,
      maxSpeedMps: maxSpeed,
      avgSpeedMps: speedSamples == 0 ? null : speedSum / speedSamples,
      maxLeanDegrees: maxLean,
    );
    await _db.upsertRide(completed);
    unawaited(_assignPlaceTitle(completed));
    return completed;
  }

  Future<void> abandonRecovered(String rideId) async {
    final ride = await _db.getRide(rideId);
    if (ride == null) return;
    await _db.upsertRide(
      ride.copyWith(
        endedAt: DateTime.now(),
        status: RideStatus.abandoned,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Arm -> auto-start
  // ---------------------------------------------------------------------

  /// Keep a dedicated foreground Dart isolate alive while armed so GPS is
  /// processed even with the screen locked. Geolocator FGS alone is not
  /// enough — native GPS can continue while Dart callbacks are frozen.
  Future<void> armForAutoStart({String? routeId}) async {
    if (_armed || isRecording) return;

    final permission = await _location.ensurePermission();
    if (!permission.granted) {
      throw LocationDeniedException(
        permission.reason ?? LocationPermissionDenyReason.denied,
      );
    }

    _armMotion.resetArm();
    _armedRouteId = routeId;
    if (routeId != null && routeId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferredArmRoutePrefKey, routeId);
    }
    _armed = true;
    _armedController.add(true);

    final started = await ArmForegroundService.start(
      onData: _onArmForegroundData,
    );
    if (!started) {
      _armed = false;
      _armedRouteId = null;
      _armedController.add(false);
      throw StateError(
        'Could not start background GPS. Allow notifications and '
        'disable battery restrictions for RiderLab, then try again.',
      );
    }
    debugPrint('CornerIQ armed with foreground GPS isolate');
    unawaited(
      _telemetry.log(
        category: TelemetryCategory.arm,
        eventType: 'armed',
        payload: {'route_id': routeId},
      ),
    );
  }

  void disarm() {
    if (!_armed) return;
    _armed = false;
    _armedRouteId = null;
    _promotingArm = false;
    _pendingG0 = null;
    _pendingSignFlip = 1;
    unawaited(_armSub?.cancel());
    _armSub = null;
    unawaited(ArmForegroundService.stop());
    _armedController.add(false);
    unawaited(
      _telemetry.log(
        category: TelemetryCategory.arm,
        eventType: 'disarmed',
      ),
    );
  }

  void _onArmForegroundData(Object data) {
    if (data is! Map) return;
    final map = Map<Object?, Object?>.from(data);
    if (map['type'] != 'arm_gps') return;

    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    final accuracy = (map['accuracy'] as num?)?.toDouble() ?? 999;
    final speed = (map['speed'] as num?)?.toDouble();
    final tsMs = map['ts'] as int?;
    final timestamp = tsMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(tsMs);

    if (isRecording) {
      _onPosition(
        Position(
          longitude: lng,
          latitude: lat,
          timestamp: timestamp,
          accuracy: accuracy,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: speed ?? -1,
          speedAccuracy: 0,
        ),
      );
      return;
    }

    if (!_armed) return;
    if (accuracy > LocationService.maxAcceptAccuracyMeters) return;

    _handleArmedSampleCoords(
      speedMps: speed,
      latitude: lat,
      longitude: lng,
      timestamp: timestamp,
    );
  }

  void _handleArmedSampleCoords({
    required double? speedMps,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) {
    if (!_armed || isRecording || _promotingArm) return;

    final shouldStart = _armMotion.feedArmedSample(
      speedMps: speedMps,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );

    if (shouldStart) {
      final routeId = _armedRouteId;
      _promotingArm = true;
      unawaited(() async {
        try {
          await _autoStart(routeId: routeId);
        } finally {
          _promotingArm = false;
        }
      }());
    }
  }

  Future<void> _autoStart({String? routeId}) async {
    try {
      unawaited(
        _telemetry.log(
          category: TelemetryCategory.arm,
          eventType: 'auto_start_triggered',
          payload: {'route_id': routeId},
        ),
      );
      final ride = await _promoteArmedToRecording(routeId: routeId);
      unawaited(
        _telemetry.log(
          category: TelemetryCategory.arm,
          eventType: 'auto_start_ok',
          rideLocalId: ride.id,
          payload: {'route_id': routeId},
        ),
      );
      _autoStartController.add(ride);
    } catch (e, st) {
      debugPrint('CornerIQ auto-start failed: $e\n$st');
      unawaited(
        _telemetry.error(
          where: 'arm.auto_start',
          error: e,
          category: TelemetryCategory.arm,
          payload: {'route_id': routeId},
        ),
      );
      if (!_armed && !isRecording) {
        unawaited(ArmForegroundService.stop());
      }
    }
  }

  /// Start dense Geolocator GPS while the arm FGS still holds priority.
  Future<Ride> _promoteArmedToRecording({String? routeId}) async {
    if (_ride != null) {
      throw StateError('A ride is already recording');
    }

    await _ensureAutoPausePref();

    final ride = Ride(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      status: RideStatus.recording,
      routeId: routeId,
    );
    await _db.upsertRide(ride);

    _ride = ride;
    _sessionPoints.clear();
    _pending.clear();
    _lastPoint = null;
    _lastStoredPoint = null;
    _distanceMeters = 0;
    _maxSpeedMps = null;
    _speedSum = 0;
    _speedSamples = 0;
    _maxLeanAbs = null;
    _maxLeanLeft = 0;
    _maxLeanRight = 0;
    _fixAcceptTimes.clear();
    _motion.resetForNewRide();

    _armed = false;
    _armedRouteId = null;
    _armedController.add(false);

    _lean.start();
    _baro.start();
    _applyPendingLeanLock();
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _flushPending(),
    );

    await ArmForegroundService.updateNotification(
      title: 'RiderLab',
      text: 'Recording ride…',
    );

    try {
      _sub = _location
          .watchPositions(
            notificationTitle: 'RiderLab',
            notificationText: 'High-precision recording…',
          )
          .listen(
            _onPosition,
            onError: (Object error, StackTrace stack) {
              debugPrint('CornerIQ ride GPS: $error');
              unawaited(
                _telemetry.error(
                  where: 'ride.gps_stream_arm',
                  error: error,
                  category: TelemetryCategory.gps,
                ),
              );
            },
          );
      await ArmForegroundService.stop();
    } catch (e, st) {
      debugPrint('CornerIQ dense GPS start failed, keep arm FGS: $e\n$st');
      unawaited(
        _telemetry.error(
          where: 'ride.dense_gps_start',
          error: e,
          category: TelemetryCategory.gps,
        ),
      );
    }

    _emit();
    debugPrint('CornerIQ promoted arm → recording ${ride.id}');
    _telemetry.bindRide(ride.id);
    unawaited(
      _telemetry.log(
        category: TelemetryCategory.ride,
        eventType: 'started',
        rideLocalId: ride.id,
        payload: {'source': 'arm_auto', 'route_id': routeId},
      ),
    );
    return ride;
  }

  // ---------------------------------------------------------------------
  // GPS handling
  // ---------------------------------------------------------------------

  void _onPosition(Position position) {
    final ride = _ride;
    if (ride == null) return;

    // Keep weaker urban fixes for continuity; drop only bad locks.
    if (position.accuracy > LocationService.maxAcceptAccuracyMeters) {
      _gpsSkipAccuracy++;
      if (_gpsSkipAccuracy == 1 || _gpsSkipAccuracy % 25 == 0) {
        unawaited(
          _telemetry.log(
            category: TelemetryCategory.gps,
            eventType: 'skip_accuracy',
            latitude: position.latitude,
            longitude: position.longitude,
            payload: {
              'accuracy_m': position.accuracy,
              'count': _gpsSkipAccuracy,
            },
          ),
        );
      }
      debugPrint(
        'CornerIQ GPS skip accuracy=${position.accuracy.toStringAsFixed(1)}m',
      );
      return;
    }

    final speedKmh = position.speed.isNaN || position.speed < 0
        ? null
        : position.speed * 3.6;
    _lean.observeForNeutral(speedKmh: speedKmh);
    _lean.observeGps(
      headingDeg: position.heading.isNaN ? null : position.heading,
      speedKmh: speedKmh,
    );

    // Signed bike lean (already relative to frozen g0).
    final rawLean = _lean.rawLeanDegrees;
    final relativeLean = _lean.leanDegrees;
    final speedMps = position.speed.isNaN || position.speed < 0
        ? null
        : position.speed;
    final point = TrackPoint(
      id: null,
      rideId: ride.id,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speedMps: speedMps,
      accuracyMeters: position.accuracy,
      heading: position.heading.isNaN ? null : position.heading,
      leanDegrees: rawLean,
      pressureHpa: _baro.pressureHpa,
      timestamp: position.timestamp,
    );
    _lastPoint = point;
    _noteGpsAccept(position.timestamp);

    _motion.feedRideSample(
      speedMps: speedMps,
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: position.timestamp,
    );

    final paused = _motion.isPaused;
    if (paused != _wasPaused) {
      _wasPaused = paused;
      unawaited(
        _telemetry.log(
          category: TelemetryCategory.ride,
          eventType: paused ? 'auto_paused' : 'auto_resumed',
          latitude: position.latitude,
          longitude: position.longitude,
          payload: {
            'speed_kmh': speedKmh,
            'accuracy_m': position.accuracy,
          },
        ),
      );
    }
    if (_motion.suggestEnd != _wasSuggestEnd) {
      _wasSuggestEnd = _motion.suggestEnd;
      if (_wasSuggestEnd) {
        unawaited(
          _telemetry.log(
            category: TelemetryCategory.ride,
            eventType: 'suggest_end',
            latitude: position.latitude,
            longitude: position.longitude,
          ),
        );
      }
    }

    unawaited(
      _telemetry.maybeRideHeartbeat(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKmh: speedKmh,
        leanDegrees: relativeLean,
        accuracyMeters: position.accuracy,
        pointCount: _sessionPoints.length,
        isPaused: paused,
      ),
    );

    if (paused) {
      // Auto-paused: don't append track points / distance so the resulting
      // gap reads naturally on the map. Keep listening + emit live status.
      _emit();
      return;
    }

    final previous = _lastStoredPoint;
    if (previous != null) {
      final jump = haversineMeters(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      final dtSec =
          point.timestamp.difference(previous.timestamp).inMilliseconds /
              1000.0;
      final maxJump = maxPlausibleJumpMeters(
        dtSeconds: dtSec,
        accuracyMeters: position.accuracy,
        previousAccuracyMeters: previous.accuracyMeters ?? 10,
      );
      // Only drop true teleports — do NOT drop fast moto hops / roundabout arcs.
      if (jump > maxJump) {
        _gpsSkipTeleport++;
        unawaited(
          _telemetry.log(
            category: TelemetryCategory.gps,
            eventType: 'skip_teleport',
            latitude: point.latitude,
            longitude: point.longitude,
            payload: {
              'jump_m': jump,
              'dt_s': dtSec,
              'max_m': maxJump,
              'count': _gpsSkipTeleport,
            },
          ),
        );
        debugPrint(
          'CornerIQ GPS skip teleport jump=${jump.toStringAsFixed(1)}m '
          'dt=${dtSec.toStringAsFixed(2)}s max=${maxJump.toStringAsFixed(1)}m',
        );
        return;
      }
      _distanceMeters += jump;
    }

    final speed = point.speedMps;
    if (speed != null) {
      _maxSpeedMps =
          _maxSpeedMps == null ? speed : (_maxSpeedMps! > speed ? _maxSpeedMps : speed);
      _speedSum += speed;
      _speedSamples++;
    }

    if (relativeLean != null) {
      final absLean = relativeLean.abs();
      _maxLeanAbs =
          _maxLeanAbs == null ? absLean : (_maxLeanAbs! > absLean ? _maxLeanAbs : absLean);
      if (relativeLean < -2) {
        _maxLeanLeft = math.max(_maxLeanLeft, -relativeLean);
      } else if (relativeLean > 2) {
        _maxLeanRight = math.max(_maxLeanRight, relativeLean);
      }
    }

    _lastStoredPoint = point;
    _sessionPoints.add(point);
    _pending.add(point);

    _ride = ride.copyWith(
      distanceMeters: _distanceMeters,
      pointCount: _sessionPoints.length,
      maxSpeedMps: _maxSpeedMps,
      avgSpeedMps: _speedSamples == 0 ? null : _speedSum / _speedSamples,
      maxLeanDegrees: _maxLeanAbs,
    );
    _emit();

    debugPrint(
      'CornerIQ OK #${_sessionPoints.length} '
      'acc=${position.accuracy.toStringAsFixed(1)}m '
      'spd=${speedKmh == null ? "--" : speedKmh.toStringAsFixed(1)} '
      'lean=${relativeLean == null ? "--" : relativeLean.toStringAsFixed(1)}° '
      'raw=${rawLean == null ? "--" : rawLean.toStringAsFixed(1)}° '
      'n=${_lean.neutralDegrees?.toStringAsFixed(1) ?? "--"} '
      'dist=${(_distanceMeters / 1000).toStringAsFixed(3)}km',
    );

    if (_pending.length >= 5) {
      unawaited(_flushPending());
    }
  }

  Future<void> _flushPending() async {
    if (_pending.isEmpty) return;
    final batch = List<TrackPoint>.from(_pending);
    _pending.clear();
    try {
      await _db.insertPointsBatch(batch);
      final ride = _ride;
      if (ride != null) {
        await _db.upsertRide(ride);
      }
    } catch (_) {
      _pending.insertAll(0, batch);
    }
  }

  void _noteGpsAccept(DateTime t) {
    _fixAcceptTimes.add(t);
    final cutoff = t.subtract(const Duration(seconds: 12));
    while (_fixAcceptTimes.isNotEmpty &&
        _fixAcceptTimes.first.isBefore(cutoff)) {
      _fixAcceptTimes.removeAt(0);
    }
  }

  double? get _liveGpsRateHz {
    if (_fixAcceptTimes.length < 3) return null;
    final spanMs = _fixAcceptTimes.last
        .difference(_fixAcceptTimes.first)
        .inMilliseconds;
    if (spanMs < 400) return null;
    return (_fixAcceptTimes.length - 1) / (spanMs / 1000.0);
  }

  void _emit() {
    final ride = _ride;
    if (ride == null) return;
    _controller.add(
      ActiveRideSnapshot(
        ride: ride,
        points: List.unmodifiable(_sessionPoints),
        lastPoint: _lastPoint,
        relativeLeanDegrees: _lean.leanDegrees,
        maxLeanLeftDegrees: _maxLeanLeft,
        maxLeanRightDegrees: _maxLeanRight,
        leanCalibrated: _lean.isCalibrated,
        isPaused: _motion.isPaused,
        suggestEnd: _motion.suggestEnd,
        pausedFor: _motion.pausedFor(),
        autoPauseEnabled: _autoPauseEnabled,
        gpsRateHz: _liveGpsRateHz,
        pressureHpa: _baro.pressureHpa,
      ),
    );
  }

  void _emitCompleted(Ride ride) {
    _controller.add(
      ActiveRideSnapshot(
        ride: ride,
        points: List.unmodifiable(_sessionPoints),
        lastPoint: _lastPoint,
        relativeLeanDegrees: _lean.leanDegrees,
        maxLeanLeftDegrees: _maxLeanLeft,
        maxLeanRightDegrees: _maxLeanRight,
        leanCalibrated: _lean.isCalibrated,
        gpsRateHz: _liveGpsRateHz,
        pressureHpa: _baro.pressureHpa ?? _lastPoint?.pressureHpa,
      ),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _armSub?.cancel();
    _flushTimer?.cancel();
    _lean.stop();
    _baro.stop();
    _fixAcceptTimes.clear();
    await _flushPending();
    await _controller.close();
    await _autoStartController.close();
    await _armedController.close();
  }
}
