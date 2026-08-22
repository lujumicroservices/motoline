/// Cloud models for group rides (Rodadas).
library;

import 'package:latlong2/latlong.dart';

import '../../../core/routing/polyline_codec.dart';
import '../../../core/routing/route_prefs.dart';

class RodadaSummary {
  const RodadaSummary({
    required this.id,
    required this.hostId,
    required this.title,
    required this.status,
    required this.inviteCode,
    this.destination,
    this.notes,
    this.meetupLat,
    this.meetupLng,
    this.finishLat,
    this.finishLng,
    this.startsAt,
    this.memberCount = 0,
    this.createdAt,
    this.updatedAt,
    this.routeGeometry,
    this.routeDistanceM,
    this.routeDurationS,
    this.routePrefs = RoutePrefs.defaults,
    this.routeProvider,
    this.myRsvp,
  });

  final String id;
  final String hostId;
  final String title;
  final String? destination;
  final String? notes;
  final double? meetupLat;
  final double? meetupLng;
  final double? finishLat;
  final double? finishLng;
  final DateTime? startsAt;
  final String status;
  final String inviteCode;
  final int memberCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? routeGeometry;
  final double? routeDistanceM;
  final double? routeDurationS;
  final RoutePrefs routePrefs;
  final String? routeProvider;
  final String? myRsvp;

  bool get isPendingInvite => myRsvp == 'pending';
  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get hasMeetup => meetupLat != null && meetupLng != null;
  bool get hasFinish => finishLat != null && finishLng != null;
  bool get hasRoutedLine =>
      routeGeometry != null && routeGeometry!.isNotEmpty;

  List<LatLng> get decodedRoute {
    final raw = routeGeometry;
    if (raw == null || raw.isEmpty) return const [];
    return decodePolyline(raw);
  }

  factory RodadaSummary.fromMap(Map<String, dynamic> map, {int? memberCount, String? myRsvp}) {
    final prefsRaw = map['route_prefs'];
    return RodadaSummary(
      id: map['id'] as String,
      hostId: map['host_id'] as String,
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? map['title'] as String
          : 'Rodada',
      destination: map['destination'] as String?,
      notes: map['notes'] as String?,
      meetupLat: (map['meetup_lat'] as num?)?.toDouble(),
      meetupLng: (map['meetup_lng'] as num?)?.toDouble(),
      finishLat: (map['finish_lat'] as num?)?.toDouble(),
      finishLng: (map['finish_lng'] as num?)?.toDouble(),
      startsAt: map['starts_at'] == null
          ? null
          : DateTime.tryParse(map['starts_at'] as String),
      status: map['status'] as String? ?? 'open',
      inviteCode: map['invite_code'] as String? ?? '',
      memberCount: memberCount ??
          (map['member_count'] as int?) ??
          ((map['rodada_members'] is List)
              ? (map['rodada_members'] as List).length
              : 0),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'] as String),
      routeGeometry: map['route_geometry'] as String?,
      routeDistanceM: (map['route_distance_m'] as num?)?.toDouble(),
      routeDurationS: (map['route_duration_s'] as num?)?.toDouble(),
      routePrefs: RoutePrefs.fromMap(
        prefsRaw is Map ? Map<String, dynamic>.from(prefsRaw) : null,
      ),
      routeProvider: map['route_provider'] as String?,
      myRsvp: myRsvp ?? map['my_rsvp'] as String?,
    );
  }
}

class RodadaMember {
  const RodadaMember({
    required this.rodadaId,
    required this.userId,
    required this.role,
    required this.rsvp,
    required this.shareLive,
    required this.shareTrack,
    required this.presence,
    this.displayName,
    this.joinedAt,
  });

  final String rodadaId;
  final String userId;
  final String role;
  final String rsvp;
  final bool shareLive;
  final bool shareTrack;
  final String presence;
  final String? displayName;
  final DateTime? joinedAt;

  bool get isHost => role == 'host' || role == 'cohost';

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (userId.length >= 8) return 'Rider ${userId.substring(0, 8)}';
    return 'Rider';
  }

  factory RodadaMember.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return RodadaMember(
      rodadaId: map['rodada_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'rider',
      rsvp: map['rsvp'] as String? ?? 'going',
      shareLive: map['share_live'] == true,
      shareTrack: map['share_track'] == true,
      presence: map['presence'] as String? ?? 'offline',
      displayName: displayName ?? map['display_name'] as String?,
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.tryParse(map['joined_at'] as String),
    );
  }
}

class RodadaLivePosition {
  const RodadaLivePosition({
    required this.rodadaId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.speedMps,
    this.heading,
    this.presence = 'riding',
    this.displayName,
  });

  /// After one missed 5‑min publish (+margin), treat pin as last-known / no signal.
  static const Duration staleAfter = Duration(minutes: 6);

  final String rodadaId;
  final String userId;
  final double latitude;
  final double longitude;
  final double? speedMps;
  final double? heading;
  final String presence;
  final DateTime updatedAt;
  final String? displayName;

  double? get speedKmh => speedMps == null ? null : speedMps! * 3.6;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (userId.length >= 8) return 'Rider ${userId.substring(0, 8)}';
    return 'Rider';
  }

  /// True when [updatedAt] is older than [staleAfter] (last good GPS ping aged out).
  bool isStale([DateTime? now]) {
    final n = now ?? DateTime.now().toUtc();
    final at = updatedAt.isUtc ? updatedAt : updatedAt.toUtc();
    return n.difference(at) > staleAfter;
  }

  factory RodadaLivePosition.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return RodadaLivePosition(
      rodadaId: map['rodada_id'] as String,
      userId: map['user_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      presence: map['presence'] as String? ?? 'riding',
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      displayName: displayName,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RodadaLivePosition &&
        other.userId == userId &&
        other.rodadaId == rodadaId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.updatedAt == updatedAt &&
        other.displayName == displayName &&
        other.presence == presence &&
        other.speedMps == speedMps &&
        other.heading == heading;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        rodadaId,
        latitude,
        longitude,
        updatedAt,
        displayName,
        presence,
        speedMps,
        heading,
      );
}

class RodadaPhoto {
  const RodadaPhoto({
    required this.id,
    required this.rodadaId,
    required this.userId,
    required this.storagePath,
    required this.createdAt,
    this.caption,
    this.latitude,
    this.longitude,
    this.displayName,
    this.takenAt,
    this.rideId,
    this.source,
    this.contentHash,
  });

  final String id;
  final String rodadaId;
  final String userId;
  final String storagePath;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final String? displayName;
  final DateTime? takenAt;
  final String? rideId;
  final String? source;
  final String? contentHash;

  factory RodadaPhoto.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return RodadaPhoto(
      id: map['id'] as String,
      rodadaId: map['rodada_id'] as String,
      userId: map['user_id'] as String,
      storagePath: map['storage_path'] as String,
      caption: map['caption'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      displayName: displayName,
      takenAt: map['taken_at'] == null
          ? null
          : DateTime.tryParse(map['taken_at'] as String),
      rideId: map['ride_id'] as String?,
      source: map['source'] as String?,
      contentHash: map['content_hash'] as String?,
    );
  }
}

class RodadaMessage {
  const RodadaMessage({
    required this.id,
    required this.rodadaId,
    required this.userId,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.displayName,
  });

  final String id;
  final String rodadaId;
  final String userId;
  final String body;
  final String kind;
  final DateTime createdAt;
  final String? displayName;

  bool get isSafety => kind == 'safety';

  factory RodadaMessage.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return RodadaMessage(
      id: map['id'] as String,
      rodadaId: map['rodada_id'] as String,
      userId: map['user_id'] as String,
      body: map['body'] as String? ?? '',
      kind: map['kind'] as String? ?? 'text',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      displayName: displayName,
    );
  }
}

class RodadaStop {
  const RodadaStop({
    required this.id,
    required this.rodadaId,
    required this.createdBy,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.sortOrder = 0,
  });

  final String id;
  final String rodadaId;
  final String createdBy;
  final String title;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final int sortOrder;

  factory RodadaStop.fromMap(Map<String, dynamic> map) {
    return RodadaStop(
      id: map['id'] as String,
      rodadaId: map['rodada_id'] as String,
      createdBy: map['created_by'] as String,
      title: map['title'] as String? ?? 'Stop',
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class RodadaRideSummary {
  const RodadaRideSummary({
    required this.id,
    required this.userId,
    required this.localId,
    required this.startedAt,
    this.endedAt,
    this.distanceMeters = 0,
    this.pointCount = 0,
    this.maxSpeedMps,
    this.lineScore,
    this.displayName,
  });

  final String id;
  final String userId;
  final String localId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final int pointCount;
  final double? maxSpeedMps;
  final int? lineScore;
  final String? displayName;

  double get distanceKm => distanceMeters / 1000;
  double? get maxSpeedKmh =>
      maxSpeedMps == null ? null : maxSpeedMps! * 3.6;

  String get riderLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (userId.length >= 8) return 'Rider ${userId.substring(0, 8)}';
    return 'Rider';
  }

  factory RodadaRideSummary.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) {
    return RodadaRideSummary(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      localId: map['local_id'] as String? ?? '',
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.tryParse(map['ended_at'] as String),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
      pointCount: (map['point_count'] as int?) ?? 0,
      maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble(),
      lineScore: map['line_score'] as int?,
      displayName: displayName,
    );
  }
}
