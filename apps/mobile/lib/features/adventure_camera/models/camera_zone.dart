/// Map geofence that starts or stops the adventure camera shutter.
enum CameraZoneAction { start, stop }

class CameraZone {
  const CameraZone({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.action,
    this.radiusMeters = 40,
    this.label,
    this.partnerId,
  });

  final String id;
  final double latitude;
  final double longitude;
  final CameraZoneAction action;
  final double radiusMeters;
  final String? label;

  /// Linked zone id: each Start must have a Stop partner (and vice versa).
  /// A Stop only fires after its partner Start was entered.
  final String? partnerId;

  CameraZone copyWith({
    String? id,
    double? latitude,
    double? longitude,
    CameraZoneAction? action,
    double? radiusMeters,
    String? label,
    String? partnerId,
    bool clearPartnerId = false,
  }) {
    return CameraZone(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      action: action ?? this.action,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
      partnerId: clearPartnerId ? null : (partnerId ?? this.partnerId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': latitude,
        'lng': longitude,
        'action': action.name,
        'radius_m': radiusMeters,
        if (label != null) 'label': label,
        if (partnerId != null) 'partner_id': partnerId,
      };

  factory CameraZone.fromJson(Map<String, dynamic> json) {
    final actionName = (json['action'] as String?) ?? 'start';
    return CameraZone(
      id: (json['id'] as String?) ?? '',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      action: actionName == 'stop'
          ? CameraZoneAction.stop
          : CameraZoneAction.start,
      radiusMeters: (json['radius_m'] as num?)?.toDouble() ?? 40,
      label: json['label'] as String?,
      partnerId: json['partner_id'] as String?,
    );
  }
}

/// Auto-link orphan starts/stops in list order (legacy prefs migration).
List<CameraZone> pairOrphanCameraZones(List<CameraZone> zones) {
  final byId = {for (final z in zones) z.id: z};
  final unpairedStarts = zones
      .where(
        (z) =>
            z.action == CameraZoneAction.start &&
            (z.partnerId == null || !byId.containsKey(z.partnerId)),
      )
      .toList();
  final unpairedStops = zones
      .where(
        (z) =>
            z.action == CameraZoneAction.stop &&
            (z.partnerId == null || !byId.containsKey(z.partnerId)),
      )
      .toList();

  if (unpairedStarts.isEmpty || unpairedStops.isEmpty) {
    return zones;
  }

  final next = {for (final z in zones) z.id: z};
  final n = unpairedStarts.length < unpairedStops.length
      ? unpairedStarts.length
      : unpairedStops.length;
  for (var i = 0; i < n; i++) {
    final s = unpairedStarts[i];
    final e = unpairedStops[i];
    next[s.id] = s.copyWith(partnerId: e.id);
    next[e.id] = e.copyWith(partnerId: s.id);
  }
  return [for (final z in zones) next[z.id]!];
}
