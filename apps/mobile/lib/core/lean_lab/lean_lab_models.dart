import 'dart:convert';

import 'grade_profile.dart';
import 'lean_lab_circuit.dart';

/// Felt lean vs app at a corner apex (pilot ground truth).
enum LeanBiasLabel {
  appHigh,
  ok,
  appLow,
  unsure;

  String get id => switch (this) {
        LeanBiasLabel.appHigh => 'app_high',
        LeanBiasLabel.ok => 'ok',
        LeanBiasLabel.appLow => 'app_low',
        LeanBiasLabel.unsure => 'unsure',
      };

  static LeanBiasLabel fromId(String? id) => switch (id) {
        'app_high' => LeanBiasLabel.appHigh,
        'app_low' => LeanBiasLabel.appLow,
        'ok' => LeanBiasLabel.ok,
        _ => LeanBiasLabel.unsure,
      };
}

enum PhonePoseId {
  portraitScreenOut,
  portraitScreenIn,
  landscape,
  other;

  String get id => switch (this) {
        PhonePoseId.portraitScreenOut => 'portrait_screen_out',
        PhonePoseId.portraitScreenIn => 'portrait_screen_in',
        PhonePoseId.landscape => 'landscape',
        PhonePoseId.other => 'other',
      };

  static PhonePoseId fromId(String? id) => switch (id) {
        'portrait_screen_out' => PhonePoseId.portraitScreenOut,
        'portrait_screen_in' => PhonePoseId.portraitScreenIn,
        'landscape' => PhonePoseId.landscape,
        _ => PhonePoseId.other,
      };
}

class LeanLabCornerLabel {
  const LeanLabCornerLabel({
    required this.mapStartIndex,
    required this.mapEndIndex,
    required this.apexIndex,
    required this.side,
    required this.appLeanDeg,
    required this.bias,
    this.feltLeanDeg,
    this.confidence = 3,
    this.avgGradePct = 0,
    this.deltaAltM = 0,
    this.vertTrend = VertTrend.unknown,
    this.notes,
  });

  final int mapStartIndex;
  final int mapEndIndex;
  final int apexIndex;

  /// left | right
  final String side;
  final double appLeanDeg;
  final LeanBiasLabel bias;
  final double? feltLeanDeg;
  final int confidence;
  final double avgGradePct;
  final double deltaAltM;
  final VertTrend vertTrend;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'map_start': mapStartIndex,
        'map_end': mapEndIndex,
        'apex_i': apexIndex,
        'side': side,
        'app_lean_deg': appLeanDeg,
        'bias': bias.id,
        'felt_lean_deg': feltLeanDeg,
        'confidence': confidence,
        'avg_grade_pct': avgGradePct,
        'delta_alt_m': deltaAltM,
        'vert_trend': vertTrendId(vertTrend),
        'notes': notes,
      };

  factory LeanLabCornerLabel.fromJson(Map<String, dynamic> json) {
    return LeanLabCornerLabel(
      mapStartIndex: (json['map_start'] as num?)?.toInt() ?? 0,
      mapEndIndex: (json['map_end'] as num?)?.toInt() ?? 0,
      apexIndex: (json['apex_i'] as num?)?.toInt() ?? 0,
      side: json['side'] as String? ?? 'right',
      appLeanDeg: (json['app_lean_deg'] as num?)?.toDouble() ?? 0,
      bias: LeanBiasLabel.fromId(json['bias'] as String?),
      feltLeanDeg: (json['felt_lean_deg'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toInt() ?? 3,
      avgGradePct: (json['avg_grade_pct'] as num?)?.toDouble() ?? 0,
      deltaAltM: (json['delta_alt_m'] as num?)?.toDouble() ?? 0,
      vertTrend: vertTrendFromId(json['vert_trend'] as String?),
      notes: json['notes'] as String?,
    );
  }
}

/// One Lean Lab ride session (calib + protocol + corner labels).
class LeanLabSession {
  const LeanLabSession({
    required this.rideId,
    required this.protocolId,
    required this.sessionType,
    required this.direction,
    required this.phoneMount,
    required this.phonePose,
    required this.frozenNeutralDeg,
    this.calibAt,
    this.corners = const [],
    this.coveragePct = 0,
    this.totalClimbM = 0,
    this.totalDescentM = 0,
    this.createdAt,
    this.synced = false,
  });

  final String rideId;
  final String protocolId;
  final LeanLabSessionType sessionType;
  final LeanLabDirection direction;
  final String phoneMount;
  final PhonePoseId phonePose;
  final double frozenNeutralDeg;
  final DateTime? calibAt;
  final List<LeanLabCornerLabel> corners;
  final double coveragePct;
  final double totalClimbM;
  final double totalDescentM;
  final DateTime? createdAt;
  final bool synced;

  bool get needsCornerLabels => corners.isEmpty;

  LeanLabSession copyWith({
    List<LeanLabCornerLabel>? corners,
    double? coveragePct,
    double? totalClimbM,
    double? totalDescentM,
    LeanLabDirection? direction,
    bool? synced,
  }) {
    return LeanLabSession(
      rideId: rideId,
      protocolId: protocolId,
      sessionType: sessionType,
      direction: direction ?? this.direction,
      phoneMount: phoneMount,
      phonePose: phonePose,
      frozenNeutralDeg: frozenNeutralDeg,
      calibAt: calibAt,
      corners: corners ?? this.corners,
      coveragePct: coveragePct ?? this.coveragePct,
      totalClimbM: totalClimbM ?? this.totalClimbM,
      totalDescentM: totalDescentM ?? this.totalDescentM,
      createdAt: createdAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, Object?> toDb() => {
        'ride_id': rideId,
        'protocol_id': protocolId,
        'session_type': sessionType.id,
        'direction': direction.id,
        'phone_mount': phoneMount,
        'phone_pose': phonePose.id,
        'frozen_neutral_deg': frozenNeutralDeg,
        'calib_at_ms': calibAt?.millisecondsSinceEpoch,
        'corners_json': jsonEncode([for (final c in corners) c.toJson()]),
        'coverage_pct': coveragePct,
        'total_climb_m': totalClimbM,
        'total_descent_m': totalDescentM,
        'created_at_ms':
            (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
        'synced': synced ? 1 : 0,
      };

  factory LeanLabSession.fromDb(Map<String, Object?> row) {
    final raw = row['corners_json'] as String? ?? '[]';
    final list = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .map((e) => LeanLabCornerLabel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return LeanLabSession(
      rideId: row['ride_id'] as String,
      protocolId: row['protocol_id'] as String? ?? BugambiliasCircuit.protocolId,
      sessionType: LeanLabSessionType.fromId(row['session_type'] as String?),
      direction: LeanLabDirection.fromId(row['direction'] as String?),
      phoneMount: row['phone_mount'] as String? ?? 'center_mount',
      phonePose: PhonePoseId.fromId(row['phone_pose'] as String?),
      frozenNeutralDeg: (row['frozen_neutral_deg'] as num?)?.toDouble() ?? 0,
      calibAt: row['calib_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['calib_at_ms'] as int),
      corners: list,
      coveragePct: (row['coverage_pct'] as num?)?.toDouble() ?? 0,
      totalClimbM: (row['total_climb_m'] as num?)?.toDouble() ?? 0,
      totalDescentM: (row['total_descent_m'] as num?)?.toDouble() ?? 0,
      createdAt: row['created_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['created_at_ms'] as int),
      synced: (row['synced'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toTrainingPayload({
    int? pointCount,
    double? distanceKm,
  }) {
    return {
      'schema': 'lean_lab.v1',
      'ride_id': rideId,
      'protocol_id': protocolId,
      'session_type': sessionType.id,
      'direction': direction.id,
      'phone_mount': phoneMount,
      'phone_pose': phonePose.id,
      'frozen_neutral_deg': frozenNeutralDeg,
      'calib_at': calibAt?.toUtc().toIso8601String(),
      'coverage_pct': coveragePct,
      'total_climb_m': totalClimbM,
      'total_descent_m': totalDescentM,
      'corners': [for (final c in corners) c.toJson()],
      'point_count': pointCount,
      'distance_km': distanceKm,
      'labeled_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
