import 'dart:convert';

import 'package:crypto/crypto.dart';

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.ownerId,
    required this.displayLabel,
    required this.status,
    this.contactUserId,
    this.seeLive = true,
    this.getOkPing = true,
    this.getSos = true,
  });

  final String id;
  final String ownerId;
  final String? contactUserId;
  final String displayLabel;
  final String status;
  final bool seeLive;
  final bool getOkPing;
  final bool getSos;

  factory TrustedContact.fromMap(Map<String, dynamic> map) {
    return TrustedContact(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      contactUserId: map['contact_user_id'] as String?,
      displayLabel: map['display_label'] as String? ?? 'Contact',
      status: map['status'] as String? ?? 'active',
      seeLive: map['see_live'] as bool? ?? true,
      getOkPing: map['get_ok_ping'] as bool? ?? true,
      getSos: map['get_sos'] as bool? ?? true,
    );
  }
}

class WatchSession {
  const WatchSession({
    required this.id,
    required this.riderId,
    required this.status,
    required this.startedAt,
    this.localRideId,
    this.cloudRideId,
    this.endedAt,
    this.riderDisplayName,
    this.shareUrl,
  });

  final String id;
  final String riderId;
  final String? localRideId;
  final String? cloudRideId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? riderDisplayName;
  final String? shareUrl;

  bool get isActive => status == 'active';

  factory WatchSession.fromMap(Map<String, dynamic> map, {String? shareUrl}) {
    return WatchSession(
      id: map['id'] as String,
      riderId: map['rider_id'] as String,
      localRideId: map['local_ride_id'] as String?,
      cloudRideId: map['cloud_ride_id'] as String?,
      status: map['status'] as String? ?? 'active',
      startedAt: DateTime.tryParse(map['started_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.tryParse(map['ended_at'] as String),
      riderDisplayName: map['rider_display_name'] as String?,
      shareUrl: shareUrl,
    );
  }
}

class WatchPosition {
  const WatchPosition({
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.speedMps,
    this.heading,
  });

  final String sessionId;
  final double latitude;
  final double longitude;
  final double? speedMps;
  final double? heading;
  final DateTime updatedAt;

  bool get isStale {
    final age = DateTime.now().toUtc().difference(
          updatedAt.isUtc ? updatedAt : updatedAt.toUtc(),
        );
    return age > const Duration(minutes: 6);
  }

  factory WatchPosition.fromMap(Map<String, dynamic> map) {
    return WatchPosition(
      sessionId: map['session_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class WatchEvent {
  const WatchEvent({
    required this.id,
    required this.sessionId,
    required this.kind,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String sessionId;
  final String kind;
  final String? note;
  final DateTime createdAt;

  factory WatchEvent.fromMap(Map<String, dynamic> map) {
    return WatchEvent(
      id: map['id'] as String? ?? '',
      sessionId: map['session_id'] as String? ?? '',
      kind: map['kind'] as String? ?? 'ok',
      note: map['note'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

String sha256Hex(String raw) {
  return sha256.convert(utf8.encode(raw)).toString();
}
