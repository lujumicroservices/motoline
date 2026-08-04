import '../../../models/track_point.dart';
import '../../../utils/geo_utils.dart';
import '../curve_event.dart';
import '../curve_types.dart';
import 'curve_stage.dart';

/// Merges adjacent arcs into compound events (S-curve, chicane, double-apex).
///
/// Does **not** leave S-curves as two separate corners.
class CompoundMergerStage implements CurvePipelineStage {
  const CompoundMergerStage();

  @override
  String get id => 'compound_merger';

  @override
  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  ) {
    if (input.length < 2) return input;
    final cfg = ctx.config;
    final samples = ctx.samples;
    final out = <CurveCandidate>[];
    var i = 0;
    while (i < input.length) {
      final a = input[i];
      if (i + 1 >= input.length) {
        out.add(a);
        break;
      }
      final b = input[i + 1];
      final gap = _gap(samples, a, b);

      final opposite = a.side != CurveSide.unknown &&
          b.side != CurveSide.unknown &&
          a.side != b.side;
      final sameSide = a.side != CurveSide.unknown && a.side == b.side;

      if (opposite &&
          gap.meters <= cfg.chicaneMaxGapMeters &&
          gap.ms <= cfg.chicaneMaxGapMs) {
        out.add(_merge(a, b, CurveGeometry.chicane));
        i += 2;
        continue;
      }
      if (opposite &&
          gap.meters <= cfg.sCurveMaxGapMeters &&
          gap.ms <= cfg.sCurveMaxGapMs) {
        out.add(_merge(a, b, CurveGeometry.sCurve));
        i += 2;
        continue;
      }
      if (sameSide &&
          gap.meters <= cfg.doubleApexMaxGapMeters &&
          gap.ms <= cfg.doubleApexMaxGapMs) {
        out.add(_merge(a, b, CurveGeometry.doubleApex));
        i += 2;
        continue;
      }

      out.add(a);
      i++;
    }
    return out;
  }

  CurveCandidate _merge(
    CurveCandidate a,
    CurveCandidate b,
    CurveGeometry geometry,
  ) {
    final dist = a.distanceMeters + b.distanceMeters;
    final dur = a.duration + b.duration;
    final heading = a.headingChangeDeg + b.headingChangeDeg;
    final avgLean = (a.avgAbsLeanDeg + b.avgAbsLeanDeg) / 2;
    final peak = a.peakAbsLeanDeg > b.peakAbsLeanDeg
        ? a.peakAbsLeanDeg
        : b.peakAbsLeanDeg;

    return CurveCandidate(
      startIndex: a.startIndex,
      endIndex: b.endIndex,
      side: geometry == CurveGeometry.doubleApex ? a.side : CurveSide.unknown,
      headingChangeDeg: heading,
      distanceMeters: dist,
      duration: dur,
      avgAbsLeanDeg: avgLean,
      peakAbsLeanDeg: peak,
      fingerprint: a.fingerprint ?? b.fingerprint,
      geometry: geometry,
      firstSide: a.side,
      secondSide: b.side,
      legIndices: [...a.legIndices, ...b.legIndices],
      confidence: 0.9,
    );
  }

  ({double meters, int ms}) _gap(
    List<TrackPoint> samples,
    CurveCandidate a,
    CurveCandidate b,
  ) {
    if (b.startIndex <= a.endIndex + 1) {
      return (meters: 0, ms: 0);
    }
    final lo = a.endIndex.clamp(0, samples.length - 1);
    final hi = b.startIndex.clamp(0, samples.length - 1);
    if (hi <= lo) return (meters: 0, ms: 0);
    final slice = samples.sublist(lo, hi + 1);
    final meters = pathDistanceMeters(slice);
    final ms =
        samples[hi].timestamp.difference(samples[lo].timestamp).inMilliseconds;
    return (meters: meters, ms: ms);
  }
}
