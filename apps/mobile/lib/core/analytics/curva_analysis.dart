import '../models/lean_sample.dart';
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
    this.leanApexIndex,
    this.leanApexDegrees,
    this.leanApexLat,
    this.leanApexLng,
    this.leanApexAtMs,
    this.geoApexIndex,
    this.geoApexLat,
    this.geoApexLng,
  });

  final RoadStretch stretch;

  /// Indices into the full ride sample list (GPS).
  final int entryIndex;

  /// Classic GPS apex (speed + lean score) — kept for coaching continuity.
  final int apexIndex;
  final int exitIndex;

  final double entrySpeedKmh;
  final double apexSpeedKmh;
  final double exitSpeedKmh;

  /// Relative lean at [apexIndex] (negative = izquierda).
  final double? apexLeanDegrees;
  final double maxLeanDegrees;

  final double distanceMeters;
  final Duration duration;

  /// Slightly padded window for the zoomed map (approach + exit context).
  final int mapStartIndex;
  final int mapEndIndex;

  /// Peak |lean| from 10 Hz series (preferred pin). Falls back to GPS index.
  final int? leanApexIndex;
  final double? leanApexDegrees;
  final double? leanApexLat;
  final double? leanApexLng;
  final int? leanApexAtMs;

  /// Max heading-rate / curvature on GPS track.
  final int? geoApexIndex;
  final double? geoApexLat;
  final double? geoApexLng;

  String get labelEs => stretch.labelEs;

  double get speedDropToApexKmh => entrySpeedKmh - apexSpeedKmh;
  double get speedGainFromApexKmh => exitSpeedKmh - apexSpeedKmh;

  /// Map pin for lean: prefer high-rate lean apex coordinates.
  int get displayApexIndex => leanApexIndex ?? apexIndex;
  double? get displayApexLat => leanApexLat;
  double? get displayApexLng => leanApexLng;

  /// Build analysis for a curva stretch; returns null for rectas / tiny windows.
  static CurvaAnalysis? fromRide({
    required List<TrackPoint> samples,
    required RoadStretch stretch,
    required double neutralLeanDegrees,
    int mapPadSamples = 6,
    List<LeanSample> leanSamples = const [],
  }) {
    if (stretch.kind != RoadKind.curva) return null;
    if (samples.length < 3) return null;

    final lo = stretch.startIndex.clamp(0, samples.length - 1);
    final hi = stretch.endIndex.clamp(lo, samples.length - 1);
    if (hi - lo < 2) return null;

    final entryIndex = lo;
    final exitIndex = hi;

    // Classic apex: score mid-window by low speed + high |lean| on GPS.
    final midStart = lo + ((hi - lo) * 0.2).round();
    final midEnd = lo + ((hi - lo) * 0.8).round();
    var apexIndex = ((midStart + midEnd) / 2).round().clamp(lo, hi);
    double? bestScore;
    for (var i = midStart; i <= midEnd; i++) {
      final s = samples[i].speedKmh;
      final raw = samples[i].leanDegrees;
      final lean = raw == null
          ? 0.0
          : relativeLeanDegrees(
              rawLeanDegrees: raw,
              neutralDegrees: neutralLeanDegrees,
            ).abs();
      final speedTerm = s ?? 40.0;
      final score = lean * 1.2 - speedTerm;
      if (bestScore == null || score > bestScore) {
        bestScore = score;
        apexIndex = i;
      }
    }

    // Geo apex: max |heading delta| in window.
    var geoApexIndex = apexIndex;
    var bestHeading = -1.0;
    for (var i = lo + 1; i <= hi; i++) {
      final a = samples[i - 1].heading;
      final b = samples[i].heading;
      if (a == null || b == null) continue;
      var d = b - a;
      if (d > 180) d -= 360;
      if (d < -180) d += 360;
      final ad = d.abs();
      if (ad > bestHeading) {
        bestHeading = ad;
        geoApexIndex = i;
      }
    }

    double speedAt(int i) {
      final s = samples[i].speedKmh;
      if (s != null) return s;
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

    // Lean apex from 10 Hz series inside the GPS time window.
    int? leanApexIndex;
    double? leanApexDegrees;
    double? leanApexLat;
    double? leanApexLng;
    int? leanApexAtMs;
    final t0 = samples[lo].timestamp.millisecondsSinceEpoch;
    final t1 = samples[hi].timestamp.millisecondsSinceEpoch;
    if (leanSamples.isNotEmpty && t1 > t0) {
      LeanSample? best;
      for (final s in leanSamples) {
        if (s.timestampMs < t0 || s.timestampMs > t1) continue;
        final rel = relativeLeanDegrees(
          rawLeanDegrees: s.leanDegrees,
          neutralDegrees: neutralLeanDegrees,
        );
        if (best == null || rel.abs() > relativeLeanDegrees(
              rawLeanDegrees: best.leanDegrees,
              neutralDegrees: neutralLeanDegrees,
            ).abs()) {
          best = s;
        }
      }
      if (best != null) {
        final leanPeak = relativeLeanDegrees(
          rawLeanDegrees: best.leanDegrees,
          neutralDegrees: neutralLeanDegrees,
        );
        leanApexAtMs = best.timestampMs;
        leanApexDegrees = leanPeak;
        if (leanPeak.abs() > maxLean) {
          maxLean = leanPeak.abs();
        }
        final mapped = interpolateLatLngAtMs(samples, best.timestampMs);
        if (mapped != null) {
          leanApexLat = mapped.$1;
          leanApexLng = mapped.$2;
          leanApexIndex = mapped.$3;
        } else {
          leanApexIndex = apexIndex;
        }
      }
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
      duration:
          samples[exitIndex].timestamp.difference(samples[entryIndex].timestamp),
      mapStartIndex: mapStart,
      mapEndIndex: mapEnd,
      leanApexIndex: leanApexIndex,
      leanApexDegrees: leanApexDegrees,
      leanApexLat: leanApexLat,
      leanApexLng: leanApexLng,
      leanApexAtMs: leanApexAtMs,
      geoApexIndex: geoApexIndex,
      geoApexLat: samples[geoApexIndex].latitude,
      geoApexLng: samples[geoApexIndex].longitude,
    );
  }
}

/// Interpolate lat/lng at [atMs] between GPS points. Returns (lat, lng, nearestIndex).
(double, double, int)? interpolateLatLngAtMs(
  List<TrackPoint> samples,
  int atMs,
) {
  if (samples.isEmpty) return null;
  if (atMs <= samples.first.timestamp.millisecondsSinceEpoch) {
    final p = samples.first;
    return (p.latitude, p.longitude, 0);
  }
  if (atMs >= samples.last.timestamp.millisecondsSinceEpoch) {
    final p = samples.last;
    return (p.latitude, p.longitude, samples.length - 1);
  }
  for (var i = 1; i < samples.length; i++) {
    final a = samples[i - 1];
    final b = samples[i];
    final ta = a.timestamp.millisecondsSinceEpoch;
    final tb = b.timestamp.millisecondsSinceEpoch;
    if (atMs < ta || atMs > tb) continue;
    if (tb == ta) {
      return (b.latitude, b.longitude, i);
    }
    final u = (atMs - ta) / (tb - ta);
    return (
      a.latitude + (b.latitude - a.latitude) * u,
      a.longitude + (b.longitude - a.longitude) * u,
      u < 0.5 ? i - 1 : i,
    );
  }
  return null;
}
