import 'package:uuid/uuid.dart';

import '../../analytics/lean_neutral.dart';
import '../../models/track_point.dart';
import 'curve_engine_config.dart';
import 'curve_event.dart';
import 'curve_types.dart';
import 'pipeline/arc_segmenter_stage.dart';
import 'pipeline/compound_merger_stage.dart';
import 'pipeline/curve_stage.dart';
import 'pipeline/geometry_classifier_stage.dart';
import 'pipeline/radius_profiler_stage.dart';
import 'pipeline/speed_profiler_stage.dart';

/// Extensible curve telemetry engine — RiderLab differentiator analytics.
///
/// Pipeline (replace/add stages without touching callers):
/// 1. [ArcSegmenterStage] — single-arc candidates
/// 2. [CompoundMergerStage] — S / chicane / double-apex as **one** event
/// 3. [GeometryClassifierStage] — sweep / standard / hairpin (drops kinks)
/// 4. Materialize phases + speed/radius profiles
class CurveEngine {
  CurveEngine({
    this.config = CurveEngineConfig.standard,
    List<CurvePipelineStage>? stages,
    Uuid? uuid,
  })  : stages = stages ??
            const [
              ArcSegmenterStage(),
              CompoundMergerStage(),
              GeometryClassifierStage(),
              SpeedProfilerStage(),
              RadiusProfilerStage(),
            ],
        _uuid = uuid ?? const Uuid();

  final CurveEngineConfig config;
  final List<CurvePipelineStage> stages;
  final Uuid _uuid;

  /// Analyze a ride sample list into typed [CurveEvent]s.
  List<CurveEvent> analyze(
    List<TrackPoint> samples, {
    double? neutralLeanDegrees,
  }) {
    if (samples.length < 4) return const [];
    final neutral = neutralLeanDegrees ?? inferNeutralLeanDegrees(samples);
    final ctx = CurveEngineContext(
      samples: samples,
      neutralLeanDegrees: neutral,
      config: config,
    );

    var candidates = <CurveCandidate>[];
    for (final stage in stages) {
      candidates = stage.process(candidates, ctx);
    }

    return [
      for (final c in candidates) _materialize(c, samples, neutral),
    ];
  }

  CurveEvent _materialize(
    CurveCandidate c,
    List<TrackPoint> samples,
    double neutral,
  ) {
    final geometry = c.geometry ?? CurveGeometry.standard;
    final lo = c.startIndex.clamp(0, samples.length - 1);
    final hi = c.endIndex.clamp(lo, samples.length - 1);

    final entry = lo;
    final exit = hi;
    var apex = ((lo + hi) / 2).round().clamp(lo, hi);

    if (!geometry.isCompound || geometry == CurveGeometry.doubleApex) {
      apex = _pickApex(samples, lo, hi, neutral);
    } else if (c.legIndices.isNotEmpty) {
      // S/chicane: apex ≈ end of first leg (transition).
      final leg0 = c.legIndices.first;
      apex = leg0.$2.clamp(lo, hi);
    }

    final entrySp = SpeedProfilerStage.speedAt(samples, entry) ?? 0;
    final apexSp = SpeedProfilerStage.speedAt(samples, apex) ?? entrySp;
    final exitSp = SpeedProfilerStage.speedAt(samples, exit) ?? apexSp;

    return CurveEvent(
      id: _uuid.v4(),
      geometry: geometry,
      startIndex: lo,
      endIndex: hi,
      distanceMeters: c.distanceMeters,
      duration: c.duration,
      headingChangeDeg: c.headingChangeDeg,
      avgAbsLeanDeg: c.avgAbsLeanDeg,
      peakAbsLeanDeg: c.peakAbsLeanDeg,
      side: c.side,
      firstSide: c.firstSide,
      secondSide: c.secondSide,
      radiusProfile: RadiusProfilerStage.profile(
        samples: samples,
        start: lo,
        end: hi,
        neutralLean: neutral,
      ),
      speedProfile: SpeedProfilerStage.profile(
        entryKmh: entrySp,
        apexKmh: apexSp,
        exitKmh: exitSp,
      ),
      entryIndex: entry,
      apexIndex: apex,
      exitIndex: exit,
      entrySpeedKmh: entrySp,
      apexSpeedKmh: apexSp,
      exitSpeedKmh: exitSp,
      fingerprint: c.fingerprint,
      confidence: c.confidence,
      legIndices: c.legIndices,
      engineVersion: config.engineId,
    );
  }

  int _pickApex(
    List<TrackPoint> samples,
    int lo,
    int hi,
    double neutral,
  ) {
    final midStart = lo + ((hi - lo) * 0.2).round();
    final midEnd = lo + ((hi - lo) * 0.8).round();
    var apex = ((midStart + midEnd) / 2).round().clamp(lo, hi);
    double? best;
    for (var i = midStart; i <= midEnd; i++) {
      final speed = samples[i].speedKmh ?? 40.0;
      final raw = samples[i].leanDegrees;
      final lean = raw == null
          ? 0.0
          : relativeLeanDegrees(
              rawLeanDegrees: raw,
              neutralDegrees: neutral,
            ).abs();
      final score = lean * 1.2 - speed;
      if (best == null || score > best) {
        best = score;
        apex = i;
      }
    }
    return apex;
  }
}
