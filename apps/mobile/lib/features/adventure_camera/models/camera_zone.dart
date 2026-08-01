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
  });

  final String id;
  final double latitude;
  final double longitude;
  final CameraZoneAction action;
  final double radiusMeters;
  final String? label;

  CameraZone copyWith({
    String? id,
    double? latitude,
    double? longitude,
    CameraZoneAction? action,
    double? radiusMeters,
    String? label,
  }) {
    return CameraZone(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      action: action ?? this.action,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': latitude,
        'lng': longitude,
        'action': action.name,
        'radius_m': radiusMeters,
        if (label != null) 'label': label,
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
    );
  }
}
