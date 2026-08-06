import '../models/track_point.dart';
import '../utils/geo_utils.dart';

enum VertTrend { climbing, flat, descending, unknown }

/// Path grade from GPS altitude (percent). Positive = climbing.
class GradeSample {
  const GradeSample({
    required this.index,
    required this.gradePct,
    required this.trend,
    this.altitudeMeters,
  });

  final int index;
  final double gradePct;
  final VertTrend trend;
  final double? altitudeMeters;
}

class GradeProfile {
  const GradeProfile({
    required this.samples,
    required this.totalClimbMeters,
    required this.totalDescentMeters,
    required this.deltaAltitudeMeters,
  });

  final List<GradeSample> samples;
  final double totalClimbMeters;
  final double totalDescentMeters;
  final double deltaAltitudeMeters;

  GradeSample? at(int index) {
    if (index < 0 || index >= samples.length) return null;
    return samples[index];
  }

  /// Mean grade over inclusive [lo, hi].
  double averageGradePct(int lo, int hi) {
    if (samples.isEmpty) return 0;
    final a = lo.clamp(0, samples.length - 1);
    final b = hi.clamp(a, samples.length - 1);
    var sum = 0.0;
    var n = 0;
    for (var i = a; i <= b; i++) {
      sum += samples[i].gradePct;
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  double altitudeDelta(int lo, int hi) {
    if (samples.isEmpty) return 0;
    final a = lo.clamp(0, samples.length - 1);
    final b = hi.clamp(a, samples.length - 1);
    final z0 = samples[a].altitudeMeters;
    final z1 = samples[b].altitudeMeters;
    if (z0 == null || z1 == null) return 0;
    return z1 - z0;
  }

  VertTrend dominantTrend(int lo, int hi) {
    final g = averageGradePct(lo, hi);
    if (g > 2.5) return VertTrend.climbing;
    if (g < -2.5) return VertTrend.descending;
    return VertTrend.flat;
  }
}

/// Build grade along [points] using a rolling window of ~[windowMeters].
GradeProfile buildGradeProfile(
  List<TrackPoint> points, {
  double windowMeters = 25,
}) {
  if (points.isEmpty) {
    return const GradeProfile(
      samples: [],
      totalClimbMeters: 0,
      totalDescentMeters: 0,
      deltaAltitudeMeters: 0,
    );
  }

  final out = <GradeSample>[];
  var climb = 0.0;
  var descent = 0.0;

  for (var i = 0; i < points.length; i++) {
    final zi = points[i].altitude;
    // Walk backward until ~windowMeters of path.
    var j = i;
    var path = 0.0;
    while (j > 0 && path < windowMeters) {
      path += haversineMeters(
        points[j - 1].latitude,
        points[j - 1].longitude,
        points[j].latitude,
        points[j].longitude,
      );
      j--;
    }
    final zj = points[j].altitude;
    double grade = 0;
    VertTrend trend = VertTrend.unknown;
    if (zi != null && zj != null && path >= 5) {
      final dAlt = zi - zj;
      grade = (dAlt / path) * 100;
      if (grade > 2.5) {
        trend = VertTrend.climbing;
      } else if (grade < -2.5) {
        trend = VertTrend.descending;
      } else {
        trend = VertTrend.flat;
      }
    } else if (zi != null) {
      trend = VertTrend.flat;
    }
    out.add(
      GradeSample(
        index: i,
        gradePct: grade,
        trend: trend,
        altitudeMeters: zi,
      ),
    );
  }

  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1].altitude;
    final b = points[i].altitude;
    if (a == null || b == null) continue;
    final d = b - a;
    if (d > 0.3) climb += d;
    if (d < -0.3) descent += -d;
  }

  final zFirst = points.first.altitude;
  final zLast = points.last.altitude;
  final delta = (zFirst != null && zLast != null) ? zLast - zFirst : 0.0;

  return GradeProfile(
    samples: out,
    totalClimbMeters: climb,
    totalDescentMeters: descent,
    deltaAltitudeMeters: delta,
  );
}

String vertTrendId(VertTrend t) => switch (t) {
      VertTrend.climbing => 'climbing',
      VertTrend.flat => 'flat',
      VertTrend.descending => 'descending',
      VertTrend.unknown => 'unknown',
    };

VertTrend vertTrendFromId(String? id) => switch (id) {
      'climbing' => VertTrend.climbing,
      'descending' => VertTrend.descending,
      'flat' => VertTrend.flat,
      _ => VertTrend.unknown,
    };
