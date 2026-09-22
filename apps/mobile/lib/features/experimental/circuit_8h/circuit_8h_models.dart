/// Experimental local survey for the 8-hour circuit: route A / route B,
/// each recorded as many times as needed, plus start / finish / checkpoints.
enum Circuit8hRouteType {
  a,
  b;

  String get id => name;

  String get label => switch (this) {
        Circuit8hRouteType.a => 'A',
        Circuit8hRouteType.b => 'B',
      };

  static Circuit8hRouteType fromId(String? raw) {
    for (final v in values) {
      if (v.id == raw) return v;
    }
    return Circuit8hRouteType.a;
  }
}

/// Which edge of the track this pass follows.
enum Circuit8hTrackEdge {
  inner,
  outer;

  String get id => name;

  static Circuit8hTrackEdge? fromId(String? raw) {
    for (final v in values) {
      if (v.id == raw) return v;
    }
    return null;
  }
}

enum Circuit8hMarkerKind {
  start,
  finish,
  checkpoint;

  String get id => name;

  static Circuit8hMarkerKind fromId(String? raw) {
    for (final v in values) {
      if (v.id == raw) return v;
    }
    return Circuit8hMarkerKind.checkpoint;
  }
}

class Circuit8hPoint {
  const Circuit8hPoint({
    required this.lat,
    required this.lng,
    required this.tsMs,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final int tsMs;
  final double? accuracyM;

  Map<String, Object?> toJson() => {
        'lat': lat,
        'lng': lng,
        'tsMs': tsMs,
        if (accuracyM != null) 'accuracyM': accuracyM,
      };

  factory Circuit8hPoint.fromJson(Map<String, dynamic> json) => Circuit8hPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        tsMs: (json['tsMs'] as num).toInt(),
        accuracyM: (json['accuracyM'] as num?)?.toDouble(),
      );
}

class Circuit8hMarker {
  const Circuit8hMarker({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.tsMs,
    this.label,
    this.accuracyM,
  });

  final String id;
  final Circuit8hMarkerKind kind;
  final double lat;
  final double lng;
  final int tsMs;
  final String? label;
  final double? accuracyM;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.id,
        'lat': lat,
        'lng': lng,
        'tsMs': tsMs,
        if (label != null) 'label': label,
        if (accuracyM != null) 'accuracyM': accuracyM,
      };

  factory Circuit8hMarker.fromJson(Map<String, dynamic> json) =>
      Circuit8hMarker(
        id: json['id'] as String? ??
            'm_${(json['tsMs'] as num?)?.toInt() ?? 0}',
        kind: Circuit8hMarkerKind.fromId(json['kind'] as String?),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        tsMs: (json['tsMs'] as num?)?.toInt() ?? 0,
        label: json['label'] as String?,
        accuracyM: (json['accuracyM'] as num?)?.toDouble(),
      );
}

class Circuit8hSession {
  const Circuit8hSession({
    required this.id,
    required this.routeType,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.points,
    this.edge,
  });

  final String id;
  final Circuit8hRouteType routeType;
  final int startedAtMs;
  final int endedAtMs;
  final List<Circuit8hPoint> points;

  /// Inside or outside edge of the track. Null on passes saved before this.
  final Circuit8hTrackEdge? edge;

  int get pointCount => points.length;

  Duration get duration =>
      Duration(milliseconds: (endedAtMs - startedAtMs).clamp(0, 1 << 31));

  Map<String, Object?> toJson() => {
        'id': id,
        'routeType': routeType.id,
        'startedAtMs': startedAtMs,
        'endedAtMs': endedAtMs,
        if (edge != null) 'edge': edge!.id,
        'points': [for (final p in points) p.toJson()],
      };

  factory Circuit8hSession.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return Circuit8hSession(
      id: json['id'] as String,
      routeType: Circuit8hRouteType.fromId(json['routeType'] as String?),
      startedAtMs: (json['startedAtMs'] as num).toInt(),
      endedAtMs: (json['endedAtMs'] as num).toInt(),
      edge: Circuit8hTrackEdge.fromId(json['edge'] as String?),
      points: [
        if (rawPoints is List)
          for (final item in rawPoints)
            if (item is Map)
              Circuit8hPoint.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class Circuit8hProject {
  const Circuit8hProject({
    this.name = 'Circuito 8 horas',
    this.sessions = const [],
    this.start,
    this.finish,
    this.checkpoints = const [],
  });

  final String name;
  final List<Circuit8hSession> sessions;
  final Circuit8hMarker? start;
  final Circuit8hMarker? finish;
  final List<Circuit8hMarker> checkpoints;

  bool get hasStart => start != null;
  bool get hasFinish => finish != null;
  int get checkpointCount => checkpoints.length;

  List<Circuit8hSession> sessionsFor(Circuit8hRouteType type) => [
        for (final s in sessions)
          if (s.routeType == type) s,
      ];

  int countFor(Circuit8hRouteType type) => sessionsFor(type).length;

  Circuit8hProject copyWith({
    String? name,
    List<Circuit8hSession>? sessions,
    Circuit8hMarker? start,
    Circuit8hMarker? finish,
    List<Circuit8hMarker>? checkpoints,
    bool clearStart = false,
    bool clearFinish = false,
  }) =>
      Circuit8hProject(
        name: name ?? this.name,
        sessions: sessions ?? this.sessions,
        start: clearStart ? null : (start ?? this.start),
        finish: clearFinish ? null : (finish ?? this.finish),
        checkpoints: checkpoints ?? this.checkpoints,
      );

  Circuit8hProject withSession(Circuit8hSession session) => copyWith(
        sessions: [...sessions, session],
      );

  Circuit8hProject withoutSession(String id) => copyWith(
        sessions: [for (final s in sessions) if (s.id != id) s],
      );

  Circuit8hProject withStart(Circuit8hMarker marker) =>
      copyWith(start: marker);

  Circuit8hProject withFinish(Circuit8hMarker marker) =>
      copyWith(finish: marker);

  Circuit8hProject withCheckpoint(Circuit8hMarker marker) => copyWith(
        checkpoints: [...checkpoints, marker],
      );

  Circuit8hProject withoutCheckpoint(String id) => copyWith(
        checkpoints: [for (final c in checkpoints) if (c.id != id) c],
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'sessions': [for (final s in sessions) s.toJson()],
        'start': start?.toJson(),
        'finish': finish?.toJson(),
        'checkpoints': [for (final c in checkpoints) c.toJson()],
      };

  factory Circuit8hProject.fromJson(Map<String, dynamic> json) {
    final raw = json['sessions'];
    final rawCp = json['checkpoints'];
    Circuit8hMarker? marker(Object? raw) {
      if (raw is! Map) return null;
      return Circuit8hMarker.fromJson(Map<String, dynamic>.from(raw));
    }

    return Circuit8hProject(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Circuito 8 horas',
      sessions: [
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              Circuit8hSession.fromJson(Map<String, dynamic>.from(item)),
      ],
      start: marker(json['start']),
      finish: marker(json['finish']),
      checkpoints: [
        if (rawCp is List)
          for (final item in rawCp)
            if (item is Map)
              Circuit8hMarker.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}
