import '../../../analytics/lean_neutral.dart';
import '../../../models/track_point.dart';
import '../curve_event.dart';
import '../curve_types.dart';
import 'curve_stage.dart';

/// Estimates radius profile from mid-window lean trend (phone proxy).
class RadiusProfilerStage implements CurvePipelineStage {
  const RadiusProfilerStage();

  @override
  String get id => 'radius_profiler';

  @override
  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  ) {
    // Applied at materialize time; keep stage for future in-place enrichment.
    return input;
  }

  static CurveRadiusProfile profile({
    required List<TrackPoint> samples,
    required int start,
    required int end,
    required double neutralLean,
  }) {
    if (end - start < 6) return CurveRadiusProfile.unknown;
    final third = ((end - start) / 3).floor().clamp(1, 1000);
    final early = _avgAbsLean(samples, start, start + third, neutralLean);
    final late = _avgAbsLean(samples, end - third, end, neutralLean);
    if (early == null || late == null) return CurveRadiusProfile.unknown;
    final delta = late - early;
    if (delta > 4) return CurveRadiusProfile.decreasing; // tighter → more lean
    if (delta < -4) return CurveRadiusProfile.increasing;
    return CurveRadiusProfile.constant;
  }

  static double? _avgAbsLean(
    List<TrackPoint> samples,
    int lo,
    int hi,
    double neutral,
  ) {
    var sum = 0.0;
    var n = 0;
    final a = lo.clamp(0, samples.length - 1);
    final b = hi.clamp(a, samples.length - 1);
    for (var i = a; i <= b; i++) {
      final raw = samples[i].leanDegrees;
      if (raw == null) continue;
      sum += relativeLeanDegrees(rawLeanDegrees: raw, neutralDegrees: neutral)
          .abs();
      n++;
    }
    if (n == 0) return null;
    return sum / n;
  }
}
