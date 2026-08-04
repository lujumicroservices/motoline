/// RiderLab curve telemetry taxonomy (differentiator analytics).
///
/// Kink is intentionally omitted — weak bends are dropped, not coached.
library;

/// Primary geometry class for a corner event.
enum CurveGeometry {
  /// Fast open arc (street exit / long-radius track).
  sweep,

  /// Classic mid corner (~70–120° heading change).
  standard,

  /// Tight U / slow technical hairpin.
  hairpin,

  /// Linked opposite turns as **one** figure (esses).
  sCurve,

  /// Short opposite pair with almost no straight between (track chicane).
  chicane,

  /// Same-side corner with two apexes / mid quiet gap.
  doubleApex,
}

/// Turn side for a single-arc event.
enum CurveSide {
  left,
  right,
  unknown,
}

/// How radius evolves through the corner (track-oriented; optional).
enum CurveRadiusProfile {
  constant,
  decreasing,
  increasing,
  unknown,
}

/// Speed character entry → apex → exit.
enum CurveSpeedProfile {
  braking,
  rolling,
  accelExit,
  technical,
  unknown,
}

extension CurveGeometryX on CurveGeometry {
  String get id => name;

  String get labelEn => switch (this) {
        CurveGeometry.sweep => 'Sweep',
        CurveGeometry.standard => 'Standard',
        CurveGeometry.hairpin => 'Hairpin',
        CurveGeometry.sCurve => 'S-curve',
        CurveGeometry.chicane => 'Chicane',
        CurveGeometry.doubleApex => 'Double apex',
      };

  String get labelEs => switch (this) {
        CurveGeometry.sweep => 'Barrido',
        CurveGeometry.standard => 'Estándar',
        CurveGeometry.hairpin => 'Horquilla',
        CurveGeometry.sCurve => 'Ese',
        CurveGeometry.chicane => 'Chicana',
        CurveGeometry.doubleApex => 'Doble ápice',
      };

  bool get isCompound =>
      this == CurveGeometry.sCurve ||
      this == CurveGeometry.chicane ||
      this == CurveGeometry.doubleApex;
}

extension CurveSideX on CurveSide {
  String get labelEs => switch (this) {
        CurveSide.left => 'Izquierda',
        CurveSide.right => 'Derecha',
        CurveSide.unknown => '',
      };
}
