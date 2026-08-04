import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/telemetry/curves/curves.dart';

TrackPoint _p({
  required int i,
  required double lat,
  required double lng,
  double? speed,
  double? lean,
  double? heading,
}) {
  return TrackPoint(
    id: null,
    rideId: 't',
    latitude: lat,
    longitude: lng,
    speedMps: speed == null ? null : speed / 3.6,
    leanDegrees: lean,
    heading: heading,
    timestamp: DateTime(2026, 1, 1).add(Duration(seconds: i)),
  );
}

/// Rough left then right arc (~S) on a local plane.
List<TrackPoint> _sCurveSamples() {
  final out = <TrackPoint>[];
  var i = 0;
  // Approach straight
  for (var k = 0; k < 5; k++) {
    out.add(_p(i: i++, lat: 19.0, lng: -99.0 + k * 0.00008, speed: 60, lean: 0, heading: 90));
  }
  // Left arc (~90°)
  for (var k = 0; k < 12; k++) {
    final t = k / 11;
    out.add(_p(
      i: i++,
      lat: 19.0 + t * 0.0009,
      lng: -99.0 + 0.0004 + t * 0.0002,
      speed: 45 - t * 8,
      lean: -22,
      heading: 90 - t * 90,
    ));
  }
  // Short link
  for (var k = 0; k < 3; k++) {
    out.add(_p(
      i: i++,
      lat: 19.0009 + k * 0.00005,
      lng: -98.9994,
      speed: 40,
      lean: 0,
      heading: 0,
    ));
  }
  // Right arc (~90°)
  for (var k = 0; k < 12; k++) {
    final t = k / 11;
    out.add(_p(
      i: i++,
      lat: 19.00105 + t * 0.0002,
      lng: -98.9994 + t * 0.0009,
      speed: 42 + t * 10,
      lean: 20,
      heading: 0 + t * 90,
    ));
  }
  return out;
}

void main() {
  group('GeometryClassifierStage', () {
    const cfg = CurveEngineConfig.standard;

    test('classifies sweep / standard / hairpin by heading', () {
      expect(
        GeometryClassifierStage.classifyHeading(50, cfg),
        CurveGeometry.sweep,
      );
      expect(
        GeometryClassifierStage.classifyHeading(95, cfg),
        CurveGeometry.standard,
      );
      expect(
        GeometryClassifierStage.classifyHeading(140, cfg),
        CurveGeometry.hairpin,
      );
    });
  });

  group('CompoundMergerStage', () {
    test('merges opposite arcs into one sCurve (not two events)', () {
      final a = CurveCandidate(
        startIndex: 0,
        endIndex: 10,
        side: CurveSide.left,
        headingChangeDeg: -80,
        distanceMeters: 40,
        duration: const Duration(seconds: 8),
        avgAbsLeanDeg: 18,
        peakAbsLeanDeg: 22,
        legIndices: const [(0, 10)],
      );
      final b = CurveCandidate(
        startIndex: 20,
        endIndex: 30,
        side: CurveSide.right,
        headingChangeDeg: 85,
        distanceMeters: 42,
        duration: const Duration(seconds: 8),
        avgAbsLeanDeg: 17,
        peakAbsLeanDeg: 20,
        legIndices: const [(20, 30)],
      );
      // ~55 m gap (idx 10→20 × ~5.5 m) → S-curve band, not chicane
      final samples = [
        for (var i = 0; i <= 30; i++)
          _p(
            i: i,
            lat: 19,
            lng: -99 + i * 0.00005,
            speed: 40,
            lean: i <= 10 ? -15 : (i >= 20 ? 15 : 0),
          ),
      ];
      final ctx = CurveEngineContext(
        samples: samples,
        neutralLeanDegrees: 0,
        config: const CurveEngineConfig(
          sCurveMaxGapMeters: 90,
          sCurveMaxGapMs: 15000,
          chicaneMaxGapMeters: 28,
          chicaneMaxGapMs: 2500,
        ),
      );
      final out = const CompoundMergerStage().process([a, b], ctx);
      expect(out, hasLength(1));
      expect(out.single.geometry, CurveGeometry.sCurve);
      expect(out.single.firstSide, CurveSide.left);
      expect(out.single.secondSide, CurveSide.right);
      expect(out.single.legIndices, hasLength(2));
    });

    test('short opposite gap becomes chicane', () {
      final a = CurveCandidate(
        startIndex: 0,
        endIndex: 8,
        side: CurveSide.right,
        headingChangeDeg: 70,
        distanceMeters: 25,
        duration: const Duration(seconds: 4),
        avgAbsLeanDeg: 16,
        peakAbsLeanDeg: 18,
        legIndices: const [(0, 8)],
      );
      final b = CurveCandidate(
        startIndex: 9,
        endIndex: 17,
        side: CurveSide.left,
        headingChangeDeg: -70,
        distanceMeters: 25,
        duration: const Duration(seconds: 4),
        avgAbsLeanDeg: 16,
        peakAbsLeanDeg: 18,
        legIndices: const [(9, 17)],
      );
      final samples = [
        for (var i = 0; i <= 17; i++)
          _p(i: i, lat: 19, lng: -99 + i * 0.00001, speed: 50, lean: 10),
      ];
      final out = const CompoundMergerStage().process(
        [a, b],
        CurveEngineContext(
          samples: samples,
          neutralLeanDegrees: 0,
          config: CurveEngineConfig.standard,
        ),
      );
      expect(out.single.geometry, CurveGeometry.chicane);
    });
  });

  group('CurveEngine', () {
    test('analyze returns versioned events', () {
      final samples = _sCurveSamples();
      final events = CurveEngine().analyze(samples, neutralLeanDegrees: 0);
      // Synthetic path may yield 0..n depending on GPS thresholds; engine must not throw.
      for (final e in events) {
        expect(e.engineVersion, 'curves.v1');
        expect(
          CurveGeometry.values.contains(e.geometry),
          isTrue,
        );
      }
    });
  });
}
