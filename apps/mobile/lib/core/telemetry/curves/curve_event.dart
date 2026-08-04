import '../../analytics/road_kind_detection.dart';
import 'curve_types.dart';

/// One coached / telemetry corner (may be compound: S, chicane, double-apex).
class CurveEvent {
  const CurveEvent({
    required this.id,
    required this.geometry,
    required this.startIndex,
    required this.endIndex,
    required this.distanceMeters,
    required this.duration,
    required this.headingChangeDeg,
    required this.avgAbsLeanDeg,
    required this.peakAbsLeanDeg,
    required this.side,
    this.firstSide,
    this.secondSide,
    this.radiusProfile = CurveRadiusProfile.unknown,
    this.speedProfile = CurveSpeedProfile.unknown,
    this.entryIndex,
    this.apexIndex,
    this.exitIndex,
    this.entrySpeedKmh,
    this.apexSpeedKmh,
    this.exitSpeedKmh,
    this.fingerprint,
    this.confidence = 1,
    this.legIndices = const [],
    this.engineVersion = CurveEvent.currentEngineVersion,
  });

  static const currentEngineVersion = 'curves.v1';

  final String id;
  final CurveGeometry geometry;

  /// Inclusive indices into the analyzed sample list.
  final int startIndex;
  final int endIndex;

  final double distanceMeters;
  final Duration duration;

  /// Net heading change over the whole event (signed: − left, + right).
  final double headingChangeDeg;

  final double avgAbsLeanDeg;
  final double peakAbsLeanDeg;

  /// Dominant side for single-arc types.
  final CurveSide side;

  /// Compound first / second leg sides (S / chicane).
  final CurveSide? firstSide;
  final CurveSide? secondSide;

  final CurveRadiusProfile radiusProfile;
  final CurveSpeedProfile speedProfile;

  final int? entryIndex;
  final int? apexIndex;
  final int? exitIndex;

  final double? entrySpeedKmh;
  final double? apexSpeedKmh;
  final double? exitSpeedKmh;

  final String? fingerprint;

  /// 0–1 classifier confidence.
  final double confidence;

  /// Optional child arc index ranges for compound events `[start,end]…`.
  final List<(int, int)> legIndices;

  final String engineVersion;

  bool get isCompound => geometry.isCompound;

  String get labelEs {
    final geo = geometry.labelEs;
    if (geometry == CurveGeometry.sCurve || geometry == CurveGeometry.chicane) {
      final a = firstSide?.labelEs ?? '';
      final b = secondSide?.labelEs ?? '';
      if (a.isNotEmpty && b.isNotEmpty) return '$geo ($a → $b)';
      return geo;
    }
    final s = side.labelEs;
    return s.isEmpty ? geo : '$geo $s';
  }

  CurveEvent copyWith({
    CurveGeometry? geometry,
    CurveSide? side,
    CurveSide? firstSide,
    CurveSide? secondSide,
    CurveRadiusProfile? radiusProfile,
    CurveSpeedProfile? speedProfile,
    int? entryIndex,
    int? apexIndex,
    int? exitIndex,
    double? entrySpeedKmh,
    double? apexSpeedKmh,
    double? exitSpeedKmh,
    double? confidence,
    List<(int, int)>? legIndices,
  }) {
    return CurveEvent(
      id: id,
      geometry: geometry ?? this.geometry,
      startIndex: startIndex,
      endIndex: endIndex,
      distanceMeters: distanceMeters,
      duration: duration,
      headingChangeDeg: headingChangeDeg,
      avgAbsLeanDeg: avgAbsLeanDeg,
      peakAbsLeanDeg: peakAbsLeanDeg,
      side: side ?? this.side,
      firstSide: firstSide ?? this.firstSide,
      secondSide: secondSide ?? this.secondSide,
      radiusProfile: radiusProfile ?? this.radiusProfile,
      speedProfile: speedProfile ?? this.speedProfile,
      entryIndex: entryIndex ?? this.entryIndex,
      apexIndex: apexIndex ?? this.apexIndex,
      exitIndex: exitIndex ?? this.exitIndex,
      entrySpeedKmh: entrySpeedKmh ?? this.entrySpeedKmh,
      apexSpeedKmh: apexSpeedKmh ?? this.apexSpeedKmh,
      exitSpeedKmh: exitSpeedKmh ?? this.exitSpeedKmh,
      fingerprint: fingerprint,
      confidence: confidence ?? this.confidence,
      legIndices: legIndices ?? this.legIndices,
      engineVersion: engineVersion,
    );
  }
}

/// Mutable draft while pipeline stages run.
class CurveCandidate {
  CurveCandidate({
    required this.startIndex,
    required this.endIndex,
    required this.side,
    required this.headingChangeDeg,
    required this.distanceMeters,
    required this.duration,
    required this.avgAbsLeanDeg,
    required this.peakAbsLeanDeg,
    this.fingerprint,
    this.geometry,
    this.firstSide,
    this.secondSide,
    this.legIndices = const [],
    this.confidence = 1,
  });

  int startIndex;
  int endIndex;
  CurveSide side;
  double headingChangeDeg;
  double distanceMeters;
  Duration duration;
  double avgAbsLeanDeg;
  double peakAbsLeanDeg;
  String? fingerprint;
  CurveGeometry? geometry;
  CurveSide? firstSide;
  CurveSide? secondSide;
  List<(int, int)> legIndices;
  double confidence;

  factory CurveCandidate.fromStretch(RoadStretch s) {
    return CurveCandidate(
      startIndex: s.startIndex,
      endIndex: s.endIndex,
      side: switch (s.side) {
        TurnSide.izquierda => CurveSide.left,
        TurnSide.derecha => CurveSide.right,
        TurnSide.none => CurveSide.unknown,
      },
      headingChangeDeg: s.headingChangeDeg,
      distanceMeters: s.distanceMeters,
      duration: s.duration,
      avgAbsLeanDeg: s.avgAbsLeanDeg,
      peakAbsLeanDeg: s.peakAbsLeanDeg,
      fingerprint: s.fingerprint,
      legIndices: [(s.startIndex, s.endIndex)],
    );
  }
}
