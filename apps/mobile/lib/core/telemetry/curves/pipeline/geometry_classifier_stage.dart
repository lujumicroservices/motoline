import '../curve_engine_config.dart';
import '../curve_event.dart';
import '../curve_types.dart';
import 'curve_stage.dart';

/// Assigns [CurveGeometry] for single-arc candidates; leaves compounds alone.
///
/// Drops weak bends (no kink type).
class GeometryClassifierStage implements CurvePipelineStage {
  const GeometryClassifierStage();

  @override
  String get id => 'geometry_classifier';

  @override
  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  ) {
    final cfg = ctx.config;
    final out = <CurveCandidate>[];
    for (final c in input) {
      if (c.geometry != null) {
        // Already compound from merger.
        out.add(c);
        continue;
      }
      final absH = c.headingChangeDeg.abs();
      if (absH < cfg.minEmitHeadingDeg && c.peakAbsLeanDeg < 18) {
        // Skip kink-class noise.
        continue;
      }
      if (absH < cfg.minEmitHeadingDeg * 0.85) {
        continue;
      }

      final geometry = classifyHeading(absH, cfg);
      c.geometry = geometry;
      c.confidence = _confidence(absH, geometry, cfg);
      out.add(c);
    }
    return out;
  }

  /// Pure helper for unit tests.
  static CurveGeometry classifyHeading(double absHeadingDeg, CurveEngineConfig cfg) {
    if (absHeadingDeg >= cfg.hairpinMinHeadingDeg) {
      return CurveGeometry.hairpin;
    }
    if (absHeadingDeg < cfg.sweepMaxHeadingDeg) {
      return CurveGeometry.sweep;
    }
    if (absHeadingDeg <= cfg.standardMaxHeadingDeg) {
      return CurveGeometry.standard;
    }
    return CurveGeometry.hairpin;
  }

  double _confidence(
    double absH,
    CurveGeometry g,
    CurveEngineConfig cfg,
  ) {
    // Higher near band centers.
    return switch (g) {
      CurveGeometry.sweep => (absH / cfg.sweepMaxHeadingDeg).clamp(0.55, 0.95),
      CurveGeometry.standard => 0.85,
      CurveGeometry.hairpin => 0.9,
      _ => 0.8,
    };
  }
}
