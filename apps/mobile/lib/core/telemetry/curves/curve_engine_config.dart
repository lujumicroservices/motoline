/// Tunable thresholds for [CurveEngine] — swap profiles for street vs track later.
class CurveEngineConfig {
  const CurveEngineConfig({
    this.sweepMaxHeadingDeg = 70,
    this.standardMaxHeadingDeg = 125,
    this.hairpinMinHeadingDeg = 125,
    this.minEmitHeadingDeg = 38,
    this.chicaneMaxGapMeters = 28,
    this.chicaneMaxGapMs = 2500,
    this.sCurveMaxGapMeters = 90,
    this.sCurveMaxGapMs = 8000,
    this.doubleApexMaxGapMeters = 45,
    this.doubleApexMaxGapMs = 4000,
    this.engineId = 'curves.v1',
  });

  /// Street + track balanced defaults.
  static const standard = CurveEngineConfig();

  /// Slightly tighter gaps / lower hairpin gate for circuit lines.
  static const track = CurveEngineConfig(
    sweepMaxHeadingDeg: 65,
    standardMaxHeadingDeg: 120,
    hairpinMinHeadingDeg: 120,
    chicaneMaxGapMeters: 35,
    chicaneMaxGapMs: 3000,
    sCurveMaxGapMeters: 70,
    sCurveMaxGapMs: 6000,
  );

  final double sweepMaxHeadingDeg;
  final double standardMaxHeadingDeg;
  final double hairpinMinHeadingDeg;

  /// Below this |heading|, candidate is dropped (no kink type).
  final double minEmitHeadingDeg;

  final double chicaneMaxGapMeters;
  final int chicaneMaxGapMs;
  final double sCurveMaxGapMeters;
  final int sCurveMaxGapMs;
  final double doubleApexMaxGapMeters;
  final int doubleApexMaxGapMs;

  final String engineId;
}
