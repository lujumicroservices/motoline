/// A loop definition that belongs to a [RouteCircuit].
///
/// Manual loops are drawn by the rider (A/B on the map). Detected loops are
/// inferred from GPS tracks of rides already tagged to that route.
class RouteLoop {
  const RouteLoop({
    required this.id,
    required this.routeId,
    required this.name,
    required this.initLat,
    required this.initLng,
    required this.endLat,
    required this.endLng,
    required this.geofenceRadiusM,
    required this.source,
    required this.createdAt,
    this.sourceRideId,
    this.isPrimary = false,
  });

  final String id;
  final String routeId;
  final String name;
  final double initLat;
  final double initLng;
  final double endLat;
  final double endLng;
  final double geofenceRadiusM;

  /// `manual` | `detected`
  final String source;
  final DateTime createdAt;
  final String? sourceRideId;

  /// When true, this is the loop used for auto-lap on the route.
  final bool isPrimary;

  bool get isReady => geofenceRadiusM > 0;

  Map<String, Object?> toMap() => {
        'id': id,
        'route_id': routeId,
        'name': name,
        'init_lat': initLat,
        'init_lng': initLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'geofence_radius_m': geofenceRadiusM,
        'source': source,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
        'source_ride_id': sourceRideId,
        'is_primary': isPrimary ? 1 : 0,
      };

  factory RouteLoop.fromMap(Map<String, Object?> map) => RouteLoop(
        id: map['id'] as String,
        routeId: map['route_id'] as String,
        name: map['name'] as String,
        initLat: (map['init_lat'] as num).toDouble(),
        initLng: (map['init_lng'] as num).toDouble(),
        endLat: (map['end_lat'] as num).toDouble(),
        endLng: (map['end_lng'] as num).toDouble(),
        geofenceRadiusM: (map['geofence_radius_m'] as num).toDouble(),
        source: map['source'] as String? ?? 'manual',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at_ms'] as int,
        ),
        sourceRideId: map['source_ride_id'] as String?,
        isPrimary: (map['is_primary'] as int?) == 1,
      );

  RouteLoop copyWith({
    String? name,
    double? initLat,
    double? initLng,
    double? endLat,
    double? endLng,
    double? geofenceRadiusM,
    String? source,
    String? sourceRideId,
    bool? isPrimary,
  }) =>
      RouteLoop(
        id: id,
        routeId: routeId,
        name: name ?? this.name,
        initLat: initLat ?? this.initLat,
        initLng: initLng ?? this.initLng,
        endLat: endLat ?? this.endLat,
        endLng: endLng ?? this.endLng,
        geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
        source: source ?? this.source,
        createdAt: createdAt,
        sourceRideId: sourceRideId ?? this.sourceRideId,
        isPrimary: isPrimary ?? this.isPrimary,
      );
}

/// Candidate closed loop found on a ride track before the user saves it.
class DetectedLoopCandidate {
  const DetectedLoopCandidate({
    required this.rideId,
    required this.startIndex,
    required this.endIndex,
    required this.initLat,
    required this.initLng,
    required this.endLat,
    required this.endLng,
    required this.pathMeters,
    required this.duration,
  });

  final String rideId;
  final int startIndex;
  final int endIndex;
  final double initLat;
  final double initLng;
  final double endLat;
  final double endLng;
  final double pathMeters;
  final Duration duration;
}
