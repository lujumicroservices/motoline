import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
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

/// Offline-first recorder: GPS points flush to SQLite in small batches.
class RideRecorder {
  RideRecorder({
    RideDatabase? database,
    LocationService? locationService,
  })  : _db = database ?? RideDatabase.instance,
        _location = locationService ?? LocationService();

  final RideDatabase _db;
  final LocationService _location;
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

    _flushTimer = Timer.periodic(
      const Duration(seconds: 3),
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
    await _flushPending();

    final completed = ride.copyWith(
      endedAt: DateTime.now(),
      status: RideStatus.completed,
      distanceMeters: _distanceMeters,
      pointCount: _sessionPoints.length,
      maxSpeedMps: _maxSpeedMps,
      avgSpeedMps: _speedSamples == 0 ? null : _speedSum / _speedSamples,
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
    var speedSum = 0.0;
    var speedSamples = 0;
    for (final p in points) {
      final s = p.speedMps;
      if (s != null && s >= 0) {
        maxSpeed = maxSpeed == null ? s : (s > maxSpeed ? s : maxSpeed);
        speedSum += s;
        speedSamples++;
      }
    }
    final completed = ride.copyWith(
      endedAt: points.isEmpty ? DateTime.now() : points.last.timestamp,
      status: RideStatus.completed,
      distanceMeters: distance,
      pointCount: points.length,
      maxSpeedMps: maxSpeed,
      avgSpeedMps: speedSamples == 0 ? null : speedSum / speedSamples,
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

    // Drop very poor fixes so the pilot line stays trustworthy.
    if (position.accuracy > 40) return;

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
      // Ignore teleport spikes from bad GPS locks.
      if (jump > 80) return;
      _distanceMeters += jump;
    }

    final speed = point.speedMps;
    if (speed != null) {
      _maxSpeedMps =
          _maxSpeedMps == null ? speed : (_maxSpeedMps! > speed ? _maxSpeedMps : speed);
      _speedSum += speed;
      _speedSamples++;
    }

    _lastPoint = point;
    _sessionPoints.add(point);
    _pending.add(point);

    _ride = ride.copyWith(
      distanceMeters: _distanceMeters,
      pointCount: _sessionPoints.length,
      maxSpeedMps: _maxSpeedMps,
      avgSpeedMps: _speedSamples == 0 ? null : _speedSum / _speedSamples,
    );
    _emit();

    if (_pending.length >= 8) {
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
      // Put points back so we do not lose track data.
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
    await _flushPending();
    await _controller.close();
  }
}
