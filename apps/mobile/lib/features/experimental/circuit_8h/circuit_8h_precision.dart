import 'dart:math' as math;

import '../../../core/services/location_service.dart';
import '../../../core/utils/geo_utils.dart';

/// Horizontal gate for Circuito 8h survey fixes only.
///
/// Ride recording still accepts up to [LocationService.maxAcceptAccuracyMeters]
/// (40 m). This lab stores a calibration track.
///
/// The stream already asks for navigation accuracy at ~10 Hz with no
/// distance filter. Fused location's reported radius on a good outdoor lock
/// is usually 3–5 m and rarely prints a smaller number, even on a multi-band
/// phone. 4 m is the tightest gate that still keeps that lock. Centimeters
/// need an external receiver or RTK.
const circuit8hMaxAcceptAccuracyMeters = 4.0;

/// A marker is the median of several tight fixes that stayed in one spot.
const circuit8hMarkerMinSamples = 3;

/// If the dwell samples spread farther than this, the bike moved.
const circuit8hMarkerMaxSpanMeters = 6.0;

enum Circuit8hFixDrop { accuracy, teleport, speed }

class Circuit8hFixDecision {
  const Circuit8hFixDecision.accept() : drop = null;

  const Circuit8hFixDecision.drop(this.drop);

  final Circuit8hFixDrop? drop;

  bool get accepted => drop == null;
}

/// Keep a survey fix only when reported accuracy is tight, the hop from the
/// previous fix is still a motorcycle move, and that hop agrees with the
/// phone's own speed.
///
/// Pass null jump/dt for the first point or for a marker (no path yet).
/// Pass null [reportedSpeedMps] when the platform did not report speed.
Circuit8hFixDecision decideCircuit8hFix({
  required double? accuracyMeters,
  double? jumpMeters,
  double? dtSeconds,
  double? reportedSpeedMps,
  double maxAccuracyMeters = circuit8hMaxAcceptAccuracyMeters,
}) {
  if (accuracyMeters == null ||
      !accuracyMeters.isFinite ||
      accuracyMeters <= 0 ||
      accuracyMeters > maxAccuracyMeters) {
    return const Circuit8hFixDecision.drop(Circuit8hFixDrop.accuracy);
  }

  if (jumpMeters != null && dtSeconds != null) {
    final maxJump = maxPlausibleJumpMeters(
      dtSeconds: dtSeconds,
      accuracyMeters: accuracyMeters,
      previousAccuracyMeters: maxAccuracyMeters,
    );
    final verdict = classifyGpsJump(
      jumpMeters: jumpMeters,
      dtSeconds: dtSeconds,
      maxJumpMeters: maxJump,
    );
    if (verdict == GpsJumpVerdict.teleport) {
      return const Circuit8hFixDecision.drop(Circuit8hFixDrop.teleport);
    }

    // Speed 0 is skipped: some phones report 0 when speed is missing, and
    // treating that as "stopped" would delete a real lap.
    if (reportedSpeedMps != null &&
        reportedSpeedMps.isFinite &&
        reportedSpeedMps >= 1 &&
        dtSeconds >= 0.4 &&
        jumpMeters >= 0) {
      final implied = jumpMeters / dtSeconds;
      final slack = math.max(8.0, reportedSpeedMps * 0.5);
      if ((implied - reportedSpeedMps).abs() > slack) {
        return const Circuit8hFixDecision.drop(Circuit8hFixDrop.speed);
      }
    }
  }

  return const Circuit8hFixDecision.accept();
}

class Circuit8hSurveySample {
  const Circuit8hSurveySample({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.tsMs,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final int tsMs;
}

class Circuit8hMarkerFix {
  const Circuit8hMarkerFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.tsMs,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final int tsMs;
}

double _spanMeters(List<Circuit8hSurveySample> samples) {
  var maxSpan = 0.0;
  for (var i = 0; i < samples.length; i++) {
    for (var j = i + 1; j < samples.length; j++) {
      final span = haversineMeters(
        samples[i].lat,
        samples[i].lng,
        samples[j].lat,
        samples[j].lng,
      );
      if (span > maxSpan) maxSpan = span;
    }
  }
  return maxSpan;
}

/// Median of the newest tight fixes that still sit in one spot.
///
/// Older samples from the ride in are ignored, so a marker can be placed
/// right after stopping. Null when the recent cluster is too small.
Circuit8hMarkerFix? medianMarkerFix(
  List<Circuit8hSurveySample> samples, {
  double maxAccuracyMeters = circuit8hMaxAcceptAccuracyMeters,
}) {
  final kept = <Circuit8hSurveySample>[
    for (final s in samples)
      if (decideCircuit8hFix(
        accuracyMeters: s.accuracyM,
        maxAccuracyMeters: maxAccuracyMeters,
      ).accepted)
        s,
  ]..sort((a, b) => a.tsMs.compareTo(b.tsMs));
  if (kept.length < circuit8hMarkerMinSamples) return null;

  final cluster = <Circuit8hSurveySample>[kept.last];
  for (var i = kept.length - 2; i >= 0; i--) {
    final next = [...cluster, kept[i]];
    if (_spanMeters(next) > circuit8hMarkerMaxSpanMeters) break;
    cluster.add(kept[i]);
  }
  if (cluster.length < circuit8hMarkerMinSamples) return null;

  final lats = [for (final s in cluster) s.lat]..sort();
  final lngs = [for (final s in cluster) s.lng]..sort();
  final accs = [for (final s in cluster) s.accuracyM]..sort();
  final mid = cluster.length ~/ 2;
  return Circuit8hMarkerFix(
    lat: lats[mid],
    lng: lngs[mid],
    accuracyM: accs[mid],
    tsMs: cluster.first.tsMs,
  );
}

/// Read fixes for [window], pausing [gap] between reads.
Future<List<Circuit8hSurveySample>> collectSurveySamples({
  required Future<Circuit8hSurveySample?> Function() read,
  Duration window = const Duration(seconds: 3),
  Duration gap = const Duration(milliseconds: 300),
  bool Function()? cancelled,
}) async {
  final out = <Circuit8hSurveySample>[];
  final deadline = DateTime.now().add(window);
  while (DateTime.now().isBefore(deadline)) {
    if (cancelled?.call() == true) break;
    final sample = await read();
    if (cancelled?.call() == true) break;
    if (sample != null) out.add(sample);
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) break;
    await Future<void>.delayed(left < gap ? left : gap);
  }
  return out;
}
