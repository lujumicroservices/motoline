import '../../../models/track_point.dart';
import '../curve_engine_config.dart';
import '../curve_event.dart';

/// Shared context passed through every pipeline stage.
class CurveEngineContext {
  CurveEngineContext({
    required this.samples,
    required this.neutralLeanDegrees,
    required this.config,
  });

  final List<TrackPoint> samples;
  final double neutralLeanDegrees;
  final CurveEngineConfig config;
}

/// Pluggable stage — add new classifiers without rewriting the engine.
abstract class CurvePipelineStage {
  String get id;

  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  );
}
