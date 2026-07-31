/// Named circuit / route for tagging rides and peer compare.
///
/// Loop A/B anchors on the route are a denormalized mirror of the primary
/// [RouteLoop] (see `route_loops`). Prefer creating / editing loops via the
/// route Loop module; session auto-lap reads these fields when armed.
class RouteCircuit {
  const RouteCircuit({
    required this.id,
    required this.name,
    this.description,
    this.isShared = false,
    required this.createdAt,
    this.ownerId,
    this.initLat,
    this.initLng,
    this.endLat,
    this.endLng,
    this.geofenceRadiusM,
  });

  final String id;
  final String name;
  final String? description;
  final bool isShared;
  final DateTime createdAt;

  /// Cloud owner (`profiles.id`). Null = created offline / legacy local row.
  final String? ownerId;

  /// Loop init marker (lat/lng), set from the active-ride HUD.
  final double? initLat;
  final double? initLng;

  /// Loop end marker (lat/lng).
  final double? endLat;
  final double? endLng;

  /// Geofence radius (meters) used for auto-lap detection around init.
  final double? geofenceRadiusM;

  bool get hasLoopInit => initLat != null && initLng != null;

  bool get hasLoopEnd => endLat != null && endLng != null;

  /// True once both init + end are marked and auto-lap can be armed.
  bool get isLoopReady => hasLoopInit && hasLoopEnd && geofenceRadiusM != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'is_shared': isShared ? 1 : 0,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
        'owner_id': ownerId,
        'init_lat': initLat,
        'init_lng': initLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'geofence_radius_m': geofenceRadiusM,
      };

  factory RouteCircuit.fromMap(Map<String, Object?> map) => RouteCircuit(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        isShared: (map['is_shared'] as int?) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at_ms'] as int,
        ),
        ownerId: map['owner_id'] as String?,
        initLat: (map['init_lat'] as num?)?.toDouble(),
        initLng: (map['init_lng'] as num?)?.toDouble(),
        endLat: (map['end_lat'] as num?)?.toDouble(),
        endLng: (map['end_lng'] as num?)?.toDouble(),
        geofenceRadiusM: (map['geofence_radius_m'] as num?)?.toDouble(),
      );

  factory RouteCircuit.fromCloud(Map<String, dynamic> map) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final sharedRaw = map['is_shared'];
    final isShared = sharedRaw is bool
        ? sharedRaw
        : sharedRaw == true || sharedRaw == 1 || sharedRaw == 'true';

    return RouteCircuit(
      id: str(map['id']) ?? '',
      name: str(map['name']) ?? '',
      description: str(map['description']),
      isShared: isShared,
      createdAt: DateTime.tryParse(str(map['created_at']) ?? '') ??
          DateTime.now(),
      ownerId: str(map['owner_id']),
      initLat: (map['init_lat'] as num?)?.toDouble(),
      initLng: (map['init_lng'] as num?)?.toDouble(),
      endLat: (map['end_lat'] as num?)?.toDouble(),
      endLng: (map['end_lng'] as num?)?.toDouble(),
      geofenceRadiusM: (map['geofence_radius_m'] as num?)?.toDouble(),
    );
  }

  RouteCircuit copyWith({
    String? name,
    String? description,
    bool? isShared,
    String? ownerId,
    double? initLat,
    double? initLng,
    double? endLat,
    double? endLng,
    double? geofenceRadiusM,
  }) =>
      RouteCircuit(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isShared: isShared ?? this.isShared,
        createdAt: createdAt,
        ownerId: ownerId ?? this.ownerId,
        initLat: initLat ?? this.initLat,
        initLng: initLng ?? this.initLng,
        endLat: endLat ?? this.endLat,
        endLng: endLng ?? this.endLng,
        geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      );
}
