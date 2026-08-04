import '../../../models/track_point.dart';
import '../curve_event.dart';
import '../curve_types.dart';
import 'curve_stage.dart';

/// Tags [CurveSpeedProfile] from entry / mid / exit speeds.
class SpeedProfilerStage implements CurvePipelineStage {
  const SpeedProfilerStage();

  @override
  String get id => 'speed_profiler';

  @override
  List<CurveCandidate> process(
    List<CurveCandidate> input,
    CurveEngineContext ctx,
  ) {
    // Speed profile is applied when materializing CurveEvent (needs apex).
    // This stage is a no-op placeholder so the pipeline stays ordered/extensible.
    return input;
  }

  static CurveSpeedProfile profile({
    required double entryKmh,
    required double apexKmh,
    required double exitKmh,
  }) {
    final drop = entryKmh - apexKmh;
    final gain = exitKmh - apexKmh;
    if (apexKmh < 35 && drop >= 8) return CurveSpeedProfile.technical;
    if (drop >= 12) return CurveSpeedProfile.braking;
    if (gain >= 10 && drop < 8) return CurveSpeedProfile.accelExit;
    if (drop.abs() < 8 && gain.abs() < 10) return CurveSpeedProfile.rolling;
    if (gain >= 8) return CurveSpeedProfile.accelExit;
    if (drop >= 6) return CurveSpeedProfile.braking;
    return CurveSpeedProfile.unknown;
  }

  static double? speedAt(List<TrackPoint> samples, int i) {
    if (samples.isEmpty) return null;
    final idx = i.clamp(0, samples.length - 1);
    final s = samples[idx].speedKmh;
    if (s != null) return s;
    for (var d = 1; d < 5; d++) {
      if (idx - d >= 0 && samples[idx - d].speedKmh != null) {
        return samples[idx - d].speedKmh;
      }
      if (idx + d < samples.length && samples[idx + d].speedKmh != null) {
        return samples[idx + d].speedKmh;
      }
    }
    return null;
  }
}
