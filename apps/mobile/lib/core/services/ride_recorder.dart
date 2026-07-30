import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'lean_sensor.dart';
import 'location_service.dart';

class ActiveRideSnapshot {
  const ActiveRideSnapshot({
    required this.ride,
    required this.points,
    required this.lastPoint,
  });

  final Ride ride;
  final List<TrackPoint> points;
  final TrackPoint? lastPoint;
}

/// Offline-first recorder: GPS + lean IMU, flushed to SQLite in batches.
class RideRecorder {
  RideRecorder({
    RideDatabase? database,
    LocationService? locationService,
    LeanSensor? leanSensor,
  })  : _db = database ?? RideDatabase.instance,
        _location = locationService ?? LocationService(),
        _lean = leanSensor ?? LeanSensor();

  final RideDatabase _db;
  final LocationService _location;
  final LeanSensor _lean;
  final _uuid = const Uuid();

  final _pending = <TrackPoint>[];
  final _controller = StreamController<ActiveRideSnapshot>.broadcast();

  StreamSubscription<Position>? _sub;
  Timer? _flushTimer;
  Ride? _ride;
  TrackPoint? _lastPoint;
  final List<TrackPoint> _sessionPoints = [];
  double _distanceMeters = 0;
  double? _maxSpeedMps;
  double _speedSum = 0;
  int _speedSamples = 0;
  double? _maxLeanAbs;

  Stream<ActiveRideSnapshot> get snapshots => _controller.stream;
  Ride? get activeRide => _ride;
  bool get isRecording => _ride?.status == RideStatus.recording;

  Future<Ride?> recoverIncompleteRide() => _db.getActiveRide();

  Future<Ride> start() async {
    if (_ride != null) {
      throw StateError('A ride is already recording');
    }

    final permission = await _location.ensurePermission();
    if (!permission.granted) {
      throw StateError(permission.message ?? 'Location permission denied');
    }

    final ride = Ride(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      status: RideStatus.recording,
    );
    await _db.upsertRide(ride);
    _ride = ride;
    _sessionPoints.clear();
    _pending.clear();
    _lastPoint = null;
    _distanceMeters = 0;
    _maxSpeedMps = null;
    _speedSum = 0;
    _speedSamples = 0;
    _maxLeanAbs = null;

    _lean.start();

    _flushTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _flushPending(),
    );

    _sub = _location.watchPositions().listen(
      _onPosition,
      onError: (Object error, StackTrace stack) {
        // Keep recording; transient GPS errors are expected outdoors.
      },
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
    _ride = null;
    _emitCompleted(completed);
    return completed;
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

  void _onPosition(Position position) {
    final ride = _ride;
    if (ride == null) return;

    // Keep weaker fixes if needed for continuity around urban canyons;
    // still reject garbage that would invent a false line.
    if (position.accuracy > 55) return;

    final lean = _lean.leanDegrees;
    final point = TrackPoint(
      id: null,
      rideId: ride.id,
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      speedMps: position.speed.isNaN || position.speed < 0
          ? null
          : position.speed,
      accuracyMeters: position.accuracy,
      heading: position.heading.isNaN ? null : position.heading,
      leanDegrees: lean,
      timestamp: position.timestamp,
    );

    final previous = _lastPoint;
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
      if (jump > maxJump) return;
      _distanceMeters += jump;
    }

    final speed = point.speedMps;
    if (speed != null) {
      _maxSpeedMps =
          _maxSpeedMps == null ? speed : (_maxSpeedMps! > speed ? _maxSpeedMps : speed);
      _speedSum += speed;
      _speedSamples++;
    }

    if (lean != null) {
      final absLean = lean.abs();
      _maxLeanAbs =
          _maxLeanAbs == null ? absLean : (_maxLeanAbs! > absLean ? _maxLeanAbs : absLean);
    }

    _lastPoint = point;
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

  void _emit() {
    final ride = _ride;
    if (ride == null) return;
    _controller.add(
      ActiveRideSnapshot(
        ride: ride,
        points: List.unmodifiable(_sessionPoints),
        lastPoint: _lastPoint,
      ),
    );
  }

  void _emitCompleted(Ride ride) {
    _controller.add(
      ActiveRideSnapshot(
        ride: ride,
        points: List.unmodifiable(_sessionPoints),
        lastPoint: _lastPoint,
      ),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _flushTimer?.cancel();
    _lean.stop();
    await _flushPending();
    await _controller.close();
  }
}
