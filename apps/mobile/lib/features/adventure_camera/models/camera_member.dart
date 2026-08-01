/// One camera in the adventure-camera group (GoPro BLE remote id + label).
class CameraMember {
  const CameraMember({
    required this.id,
    required this.remoteId,
    required this.displayName,
    this.enabled = true,
  });

  /// Stable local id (uuid).
  final String id;

  /// BLE remote id used for preferred reconnect.
  final String remoteId;

  final String displayName;
  final bool enabled;

  CameraMember copyWith({
    String? id,
    String? remoteId,
    String? displayName,
    bool? enabled,
  }) {
    return CameraMember(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'remote_id': remoteId,
        'name': displayName,
        'enabled': enabled,
      };

  factory CameraMember.fromJson(Map<String, dynamic> json) {
    return CameraMember(
      id: (json['id'] as String?) ?? '',
      remoteId: (json['remote_id'] as String?) ??
          (json['remoteId'] as String?) ??
          '',
      displayName: (json['name'] as String?) ??
          (json['displayName'] as String?) ??
          'GoPro',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Result of a nearby GoPro BLE scan (for “add to group”).
class GoProScanHit {
  const GoProScanHit({
    required this.remoteId,
    required this.displayName,
    this.rssi,
  });

  final String remoteId;
  final String displayName;
  final int? rssi;
}
