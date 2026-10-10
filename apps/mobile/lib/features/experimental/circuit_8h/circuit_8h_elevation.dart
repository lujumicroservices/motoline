import 'circuit_8h_models.dart';
import '../../../core/utils/geo_utils.dart';

/// Vertical summary from phone GPS altitude (MSL when available).
/// Vertical noise is typically worse than horizontal (~10–30 m); use for
/// relative relief / grade, not survey-grade elevation.
class Circuit8hElevationStats {
  const Circuit8hElevationStats({
    required this.sampleCount,
    this.lastAltM,
    this.minAltM,
    this.maxAltM,
    this.climbM = 0,
    this.descentM = 0,
  });

  final int sampleCount;
  final double? lastAltM;
  final double? minAltM;
  final double? maxAltM;
  final double climbM;
  final double descentM;

  bool get hasAltitude => sampleCount > 0 && lastAltM != null;
}

/// Ignore tiny vertical jitter between fixes.
const circuit8hAltitudeNoiseFloorM = 0.5;

Circuit8hElevationStats circuit8hElevationStats(List<Circuit8hPoint> points) {
  double? last;
  double? minZ;
  double? maxZ;
  var climb = 0.0;
  var descent = 0.0;
  var n = 0;

  for (final p in points) {
    final z = p.altM;
    if (z == null || !z.isFinite) continue;
    n++;
    minZ = minZ == null ? z : (z < minZ ? z : minZ);
    maxZ = maxZ == null ? z : (z > maxZ ? z : maxZ);
    if (last != null) {
      final d = z - last;
      if (d > circuit8hAltitudeNoiseFloorM) climb += d;
      if (d < -circuit8hAltitudeNoiseFloorM) descent += -d;
    }
    last = z;
  }

  return Circuit8hElevationStats(
    sampleCount: n,
    lastAltM: last,
    minAltM: minZ,
    maxAltM: maxZ,
    climbM: climb,
    descentM: descent,
  );
}

/// Path grade (%) over ~[windowMeters] using GPS altitude.
double? circuit8hGradePctAt(
  List<Circuit8hPoint> points,
  int index, {
  double windowMeters = 25,
}) {
  if (index < 0 || index >= points.length) return null;
  final zi = points[index].altM;
  if (zi == null || !zi.isFinite) return null;
  var j = index;
  var path = 0.0;
  while (j > 0 && path < windowMeters) {
    path += haversineMeters(
      points[j - 1].lat,
      points[j - 1].lng,
      points[j].lat,
      points[j].lng,
    );
    j--;
  }
  final zj = points[j].altM;
  if (zj == null || !zj.isFinite || path < 5) return null;
  return ((zi - zj) / path) * 100;
}
