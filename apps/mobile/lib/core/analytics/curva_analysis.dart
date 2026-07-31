import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'lean_neutral.dart';
import 'road_kind_detection.dart';

/// Pilot-oriented breakdown of a single curva: entrada → ápice → salida.
class CurvaAnalysis {
  const CurvaAnalysis({
    required this.stretch,
    required this.entryIndex,
    required this.apexIndex,
    required this.exitIndex,
    required this.entrySpeedKmh,
    required this.apexSpeedKmh,
    required this.exitSpeedKmh,
    required this.apexLeanDegrees,
    required this.maxLeanDegrees,
    required this.distanceMeters,
    required this.duration,
    required this.mapStartIndex,
    required this.mapEndIndex,
  });

  final RoadStretch stretch;

  /// Indices into the full ride sample list.
  final int entryIndex;
  final int apexIndex;
  final int exitIndex;

  final double entrySpeedKmh;
  final double apexSpeedKmh;
  final double exitSpeedKmh;

  /// Relative lean at apex (negative = izquierda).
  final double? apexLeanDegrees;
  final double maxLeanDegrees;

  final double distanceMeters;
  final Duration duration;

  /// Slightly padded window for the zoomed map (approach + exit context).
  final int mapStartIndex;
  final int mapEndIndex;

  String get labelEs => stretch.labelEs;

  double get speedDropToApexKmh => entrySpeedKmh - apexSpeedKmh;
  double get speedGainFromApexKmh => exitSpeedKmh - apexSpeedKmh;

  /// Build analysis for a curva stretch; returns null for rectas / tiny windows.
  static CurvaAnalysis? fromRide({
    required List<TrackPoint> samples,
    required RoadStretch stretch,
    required double neutralLeanDegrees,
    int mapPadSamples = 6,
  }) {
    if (stretch.kind != RoadKind.curva) return null;
    if (samples.length < 3) return null;

    final lo = stretch.startIndex.clamp(0, samples.length - 1);
    final hi = stretch.endIndex.clamp(lo, samples.length - 1);
    if (hi - lo < 2) return null;

    final entryIndex = lo;
    final exitIndex = hi;

    // Apex: slowest point in the middle 60% of the curva (classic mini-speed).
    // Fallback: peak absolute lean in that window.
    final midStart = lo + ((hi - lo) * 0.2).round();
    final midEnd = lo + ((hi - lo) * 0.8).round();
    var apexIndex = ((midStart + midEnd) / 2).round().clamp(lo, hi);
    double? bestSpeed;
    for (var i = midStart; i <= midEnd; i++) {
      final s = samples[i].speedKmh;
      if (s == null) continue;
      if (bestSpeed == null || s < bestSpeed) {
        bestSpeed = s;
        apexIndex = i;
      }
    }

    if (bestSpeed == null) {
      var peakLean = -1.0;
      for (var i = midStart; i <= midEnd; i++) {
        final raw = samples[i].leanDegrees;
        if (raw == null) continue;
        final abs = relativeLeanDegrees(
          rawLeanDegrees: raw,
          neutralDegrees: neutralLeanDegrees,
        ).abs();
        if (abs > peakLean) {
          peakLean = abs;
          apexIndex = i;
        }
      }
    }

    double speedAt(int i) {
      final s = samples[i].speedKmh;
      if (s != null) return s;
      // Nearby fallback.
      for (var d = 1; d < 5; d++) {
        if (i - d >= lo) {
          final a = samples[i - d].speedKmh;
          if (a != null) return a;
        }
        if (i + d <= hi) {
          final b = samples[i + d].speedKmh;
          if (b != null) return b;
        }
      }
      return 0;
    }

    double? leanAt(int i) {
      final raw = samples[i].leanDegrees;
      if (raw == null) return null;
      return relativeLeanDegrees(
        rawLeanDegrees: raw,
        neutralDegrees: neutralLeanDegrees,
      );
    }

    var maxLean = 0.0;
    for (var i = lo; i <= hi; i++) {
      final lean = leanAt(i);
      if (lean != null && lean.abs() > maxLean) maxLean = lean.abs();
    }

    final slice = samples.sublist(lo, hi + 1);
    final mapStart = (lo - mapPadSamples).clamp(0, samples.length - 1);
    final mapEnd = (hi + mapPadSamples).clamp(0, samples.length - 1);

    return CurvaAnalysis(
      stretch: stretch,
      entryIndex: entryIndex,
      apexIndex: apexIndex,
      exitIndex: exitIndex,
      entrySpeedKmh: speedAt(entryIndex),
      apexSpeedKmh: speedAt(apexIndex),
      exitSpeedKmh: speedAt(exitIndex),
      apexLeanDegrees: leanAt(apexIndex),
      maxLeanDegrees: maxLean,
      distanceMeters: pathDistanceMeters(slice),
      duration: samples[exitIndex].timestamp.difference(samples[entryIndex].timestamp),
      mapStartIndex: mapStart,
      mapEndIndex: mapEnd,
    );
  }
}
