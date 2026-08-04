import '../../../analytics/road_kind_detection.dart';
import '../curve_event.dart';
import 'curve_stage.dart';

/// Turns the GPS line into single-arc curva candidates.
///
/// Uses existing stretch detection (which splits on side change) so compound
/// merger can re-join S / chicane / double-apex as **one** event.
class ArcSegmenterStage implements CurvePipelineStage {
  const ArcSegmenterStage();

  @override
  String get id => 'arc_segmenter';

  @override
  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  ) {
    final stretches = detectRoadStretches(
      ctx.samples,
      neutralLeanDegrees: ctx.neutralLeanDegrees,
    );
    return [
      for (final s in stretches)
        if (s.kind == RoadKind.curva) CurveCandidate.fromStretch(s),
    ];
  }
}
