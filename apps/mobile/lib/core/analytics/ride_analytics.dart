import 'dart:math' as math;

import '../models/ride.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'brake_detection.dart';
import 'lean_neutral.dart';
import 'road_kind_detection.dart';

class RideAnalytics {
  RideAnalytics({
    required this.ride,
    required this.points,
    double? distanceMetersOverride,
    double? neutralLeanOverride,
    DateTime? seriesOrigin,
    this.mapIndexOffset = 0,
  })  : samples = _dedupe(points),
        _distanceMetersOverride = distanceMetersOverride,
        _seriesOrigin = seriesOrigin {
    neutralLeanDegrees =
        neutralLeanOverride ?? inferNeutralLeanDegrees(samples);
    leanSides = leanSideStats(
      samples: samples,
      neutralDegrees: neutralLeanDegrees,
    );
    brakeEvents = detectBrakeEvents(samples);
    roadStretches = detectRoadStretches(
      samples,
      neutralLeanDegrees: neutralLeanDegrees,
    );
  }

  final Ride ride;
  final List<TrackPoint> points;

  /// One sample per unique timestamp (GPS sometimes emits duplicates).
  final List<TrackPoint> samples;

  /// Index of [samples].first in the parent full-ride list (0 if full ride).
  final int mapIndexOffset;

  final double? _distanceMetersOverride;
  final DateTime? _seriesOrigin;

  /// Inferred pocket/mount upright offset (raw − neutral = bike lean).
  late final double neutralLeanDegrees;

  late final LeanSideStats leanSides;

  /// Brake applications inferred from GPS speed drop.
  late final List<BrakeEvent> brakeEvents;

  /// Recta / curva stretches from heading change.
  late final List<RoadStretch> roadStretches;

  bool get hasData => samples.isNotEmpty;

  bool get isSegment => mapIndexOffset > 0 || _distanceMetersOverride != null;

  Duration get duration {
    if (samples.length < 2) {
      return isSegment ? Duration.zero : ride.duration;
    }
    return samples.last.timestamp.difference(samples.first.timestamp);
  }

  double get distanceKm {
    final override = _distanceMetersOverride;
    if (override != null) return override / 1000.0;
    if (samples.length >= 2) {
      return pathDistanceMeters(samples) / 1000.0;
    }
    return ride.distanceKm;
  }

  double? get maxSpeedKmh {
    double? max;
    for (final p in samples) {
      final s = p.speedKmh;
      if (s == null) continue;
      max = max == null ? s : math.max(max, s);
    }
    if (max != null) return max;
    return isSegment ? null : ride.maxSpeedKmh;
  }

  double? get avgMovingSpeedKmh {
    final moving = <double>[];
    for (final p in samples) {
      final s = p.speedKmh;
      if (s != null && s >= 3) moving.add(s);
    }
    if (moving.isEmpty) {
      return isSegment ? null : ride.avgSpeedKmh;
    }
    return moving.reduce((a, b) => a + b) / moving.length;
  }

  double? get maxLeanAbs {
    if (leanSides.sampleCount == 0) {
      return isSegment ? null : ride.maxLeanDegrees;
    }
    return leanSides.peakAbs;
  }

  double get maxLeanLeft => leanSides.maxLeftDegrees;
  double get maxLeanRight => leanSides.maxRightDegrees;

  /// Peak relative lean sample for the gauge needle (last strong lean or 0).
  double get displayLeanDegrees {
    if (samples.isEmpty) return 0;
    TrackPoint? peak;
    var peakAbs = -1.0;
    for (final p in samples) {
      final raw = p.leanDegrees;
      if (raw == null) continue;
      final rel = relativeLeanDegrees(
        rawLeanDegrees: raw,
        neutralDegrees: neutralLeanDegrees,
      );
      if (rel.abs() >= peakAbs) {
        peakAbs = rel.abs();
        peak = p;
      }
    }
    if (peak?.leanDegrees == null) return 0;
    return relativeLeanDegrees(
      rawLeanDegrees: peak!.leanDegrees!,
      neutralDegrees: neutralLeanDegrees,
    );
  }

  double? get avgGpsAccuracyM {
    final vals = samples
        .map((p) => p.accuracyMeters)
        .whereType<double>()
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double? get bestGpsAccuracyM {
    final vals = samples
        .map((p) => p.accuracyMeters)
        .whereType<double>()
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce(math.min);
  }

  double? get sampleRateHz {
    if (samples.length < 2) return null;
    final secs = samples.last.timestamp
            .difference(samples.first.timestamp)
            .inMilliseconds /
        1000.0;
    if (secs <= 0) return null;
    return samples.length / secs;
  }

  /// 0–100 composite “line quality” score for hero display.
  int get lineScore {
    if (!hasData) return 0;
    final acc = avgGpsAccuracyM ?? 40;
    final hz = sampleRateHz ?? 0;
    final coverage = math.min(1.0, samples.length / 60.0);
    final accScore = (1 - ((acc - 3).clamp(0, 37) / 37)) * 45;
    final hzScore = (hz.clamp(0, 3) / 3) * 35;
    final coverScore = coverage * 20;
    return (accScore + hzScore + coverScore).round().clamp(0, 100);
  }

  String get lineScoreLabel {
    final s = lineScore;
    if (s >= 85) return 'Exceptional lock';
    if (s >= 70) return 'Strong lock';
    if (s >= 50) return 'Solid lock';
    if (s >= 30) return 'Usable lock';
    return 'Weak lock';
  }

  DateTime get _origin =>
      _seriesOrigin ??
      (samples.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : samples.first.timestamp);

  List<TimedValue> get speedSeries => [
        for (final p in samples)
          if (p.speedKmh != null)
            TimedValue(
              seconds:
                  p.timestamp.difference(_origin).inMilliseconds / 1000.0,
              value: p.speedKmh!,
            ),
      ];

  /// Relative bike lean (0 = upright after pocket neutral removed).
  List<TimedValue> get leanSeries => [
        for (final p in samples)
          if (p.leanDegrees != null)
            TimedValue(
              seconds:
                  p.timestamp.difference(_origin).inMilliseconds / 1000.0,
              value: relativeLeanDegrees(
                rawLeanDegrees: p.leanDegrees!,
                neutralDegrees: neutralLeanDegrees,
              ),
            ),
      ];

  List<TimedValue> get accuracySeries => [
        for (final p in samples)
          if (p.accuracyMeters != null)
            TimedValue(
              seconds:
                  p.timestamp.difference(_origin).inMilliseconds / 1000.0,
              value: p.accuracyMeters!,
            ),
      ];

  double get totalSeconds {
    if (samples.length < 2) return 0;
    return samples.last.timestamp
            .difference(samples.first.timestamp)
            .inMilliseconds /
        1000.0;
  }

  double get windowStartSeconds {
    if (samples.isEmpty) return 0;
    return samples.first.timestamp.difference(_origin).inMilliseconds / 1000.0;
  }

  double get windowEndSeconds {
    if (samples.isEmpty) return 0;
    return samples.last.timestamp.difference(_origin).inMilliseconds / 1000.0;
  }

  /// Nearest sample index (local to this analytics view) for a scrub time.
  int indexForSeconds(double seconds) {
    if (samples.isEmpty) return 0;
    final targetMs =
        _origin.millisecondsSinceEpoch + (seconds * 1000).round();
    var best = 0;
    var bestDelta = 1 << 62;
    for (var i = 0; i < samples.length; i++) {
      final d = (samples[i].timestamp.millisecondsSinceEpoch - targetMs).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = i;
      }
    }
    return best;
  }

  double secondsForIndex(int index) {
    if (samples.isEmpty) return 0;
    final i = index.clamp(0, samples.length - 1);
    return samples[i].timestamp.difference(_origin).inMilliseconds / 1000.0;
  }

  double relativeLeanAt(int index) {
    if (samples.isEmpty) return 0;
    final i = index.clamp(0, samples.length - 1);
    final raw = samples[i].leanDegrees;
    if (raw == null) return 0;
    return relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: neutralLeanDegrees,
    );
  }

  /// Contiguous window of this ride for segment zoom + metrics.
  RideAnalytics segment(int startInclusive, int endInclusive) {
    if (samples.isEmpty) return this;
    final lo = startInclusive.clamp(0, samples.length - 1);
    final hi = endInclusive.clamp(lo, samples.length - 1);
    final slice = samples.sublist(lo, hi + 1);
    return RideAnalytics(
      ride: ride,
      points: slice,
      distanceMetersOverride: pathDistanceMeters(slice),
      neutralLeanOverride: neutralLeanDegrees,
      seriesOrigin: _origin,
      mapIndexOffset: mapIndexOffset + lo,
    );
  }

  static List<TrackPoint> _dedupe(List<TrackPoint> points) {
    if (points.isEmpty) return const [];
    final out = <TrackPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      if (points[i].timestamp.millisecondsSinceEpoch !=
          out.last.timestamp.millisecondsSinceEpoch) {
        out.add(points[i]);
      }
    }
    return out;
  }
}

class TimedValue {
  const TimedValue({required this.seconds, required this.value});
  final double seconds;
  final double value;
}

class FleetSummary {
  const FleetSummary({
    required this.rideCount,
    required this.totalDistanceKm,
    required this.totalDuration,
    required this.bestMaxSpeedKmh,
    required this.bestMaxLean,
    required this.totalPoints,
  });

  final int rideCount;
  final double totalDistanceKm;
  final Duration totalDuration;
  final double? bestMaxSpeedKmh;
  final double? bestMaxLean;
  final int totalPoints;

  factory FleetSummary.fromRides(List<Ride> rides) {
    final completed =
        rides.where((r) => r.status == RideStatus.completed).toList();
    var distance = 0.0;
    var duration = Duration.zero;
    var points = 0;
    double? bestSpeed;
    double? bestLean;
    for (final r in completed) {
      distance += r.distanceKm;
      duration += r.duration;
      points += r.pointCount;
      if (r.maxSpeedKmh != null) {
        bestSpeed = bestSpeed == null
            ? r.maxSpeedKmh
            : math.max(bestSpeed, r.maxSpeedKmh!);
      }
      if (r.maxLeanDegrees != null) {
        bestLean = bestLean == null
            ? r.maxLeanDegrees
            : math.max(bestLean, r.maxLeanDegrees!);
      }
    }
    return FleetSummary(
      rideCount: completed.length,
      totalDistanceKm: distance,
      totalDuration: duration,
      bestMaxSpeedKmh: bestSpeed,
      bestMaxLean: bestLean,
      totalPoints: points,
    );
  }
}

String formatDurationLong(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }
  return formatDuration(d);
}
