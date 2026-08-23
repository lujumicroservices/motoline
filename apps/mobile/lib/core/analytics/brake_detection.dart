import '../models/track_point.dart';
import '../../theme/ride_viz_palette.dart';
import 'track_lod.dart';

/// Inferred brake application from GPS speed drop (no brake sensor).
class BrakeEvent {
  const BrakeEvent({
    required this.startIndex,
    required this.endIndex,
    required this.peakDecelMps2,
    required this.avgDecelMps2,
    required this.speedDropKmh,
    required this.startSpeedKmh,
    required this.endSpeedKmh,
    required this.duration,
    required this.hardness,
  });

  final int startIndex;
  final int endIndex;

  /// Peak deceleration magnitude (m/s²), always ≥ 0.
  final double peakDecelMps2;

  /// Average deceleration magnitude over the event (m/s²).
  final double avgDecelMps2;

  final double speedDropKmh;
  final double startSpeedKmh;
  final double endSpeedKmh;
  final Duration duration;
  final BrakeHardness hardness;

  int get sampleCount => endIndex - startIndex + 1;

  String get hardnessLabel => switch (hardness) {
        BrakeHardness.light => 'Light',
        BrakeHardness.medium => 'Medium',
        BrakeHardness.hard => 'Hard',
      };

  /// 0–1 UI bar from peak decel (~1.5 → 8 m/s²).
  double get hardnessFraction =>
      ((peakDecelMps2 - 1.5) / 6.5).clamp(0.05, 1.0);
}

/// Detect brake events from consecutive GPS speed samples.
///
/// Uses Δv/Δt. Positive thresholds are deceleration magnitudes (m/s²).
List<BrakeEvent> detectBrakeEvents(
  List<TrackPoint> samples, {
  double enterDecelMps2 = 1.4,
  double exitDecelMps2 = 0.7,
  double minSpeedDropKmh = 4,
  Duration minDuration = const Duration(milliseconds: 350),
  int minSamples = 2,
}) {
  if (samples.length < 3) return const [];

  final events = <BrakeEvent>[];
  int? runStart;
  var peak = 0.0;
  var sumDecel = 0.0;
  var decelSamples = 0;

  void closeRun(int endIndex) {
    final start = runStart;
    if (start == null) return;
    if (endIndex - start + 1 < minSamples) {
      runStart = null;
      return;
    }
    final t0 = samples[start].timestamp;
    final t1 = samples[endIndex].timestamp;
    final dur = t1.difference(t0);
    if (dur < minDuration) {
      runStart = null;
      return;
    }

    final v0 = samples[start].speedKmh ?? 0;
    final v1 = samples[endIndex].speedKmh ?? 0;
    final drop = v0 - v1;
    if (drop < minSpeedDropKmh) {
      runStart = null;
      return;
    }

    final avg = decelSamples == 0 ? peak : sumDecel / decelSamples;
    events.add(
      BrakeEvent(
        startIndex: start,
        endIndex: endIndex,
        peakDecelMps2: peak,
        avgDecelMps2: avg,
        speedDropKmh: drop,
        startSpeedKmh: v0,
        endSpeedKmh: v1,
        duration: dur,
        hardness: _hardnessFor(peak),
      ),
    );
    runStart = null;
  }

  for (var i = 1; i < samples.length; i++) {
    final prev = samples[i - 1];
    final cur = samples[i];
    final v0 = prev.speedMps;
    final v1 = cur.speedMps;
    if (v0 == null || v1 == null || v0 < 0 || v1 < 0) {
      if (runStart != null) closeRun(i - 1);
      continue;
    }
    final dt =
        cur.timestamp.difference(prev.timestamp).inMilliseconds / 1000.0;
    if (dt < 0.05 || dt > 3.0) {
      if (runStart != null) closeRun(i - 1);
      continue;
    }

    final accel = (v1 - v0) / dt; // m/s² (negative = slowing)
    final decel = -accel;

    if (runStart == null) {
      if (decel >= enterDecelMps2 && v0 >= 2.0) {
        runStart = i - 1;
        peak = decel;
        sumDecel = decel;
        decelSamples = 1;
      }
    } else {
      if (decel >= exitDecelMps2) {
        if (decel > peak) peak = decel;
        if (decel > 0) {
          sumDecel += decel;
          decelSamples++;
        }
      } else {
        closeRun(i - 1);
      }
    }
  }
  if (runStart != null) closeRun(samples.length - 1);

  return events;
}

BrakeHardness _hardnessFor(double peakDecelMps2) {
  if (peakDecelMps2 >= 5.0) return BrakeHardness.hard;
  if (peakDecelMps2 >= 3.0) return BrakeHardness.medium;
  return BrakeHardness.light;
}

/// Project brake events from [source] (full-rate lab) onto [target]
/// (downsampled overview map). Does not copy GPS or re-run detection —
/// only remaps indices, O(events × log overview).
List<BrakeEvent> remapBrakeEvents({
  required List<BrakeEvent> events,
  required List<TrackPoint> source,
  required List<TrackPoint> target,
}) {
  if (events.isEmpty || source.isEmpty || target.isEmpty) {
    return const [];
  }
  if (identical(source, target)) return events;

  int indexAt(DateTime t) => nearestIndexByTime(
        target,
        (p) => p.timestamp.millisecondsSinceEpoch,
        t.millisecondsSinceEpoch,
      );

  final out = <BrakeEvent>[];
  for (final e in events) {
    final i0 = e.startIndex.clamp(0, source.length - 1);
    final i1 = e.endIndex.clamp(0, source.length - 1);
    var lo = indexAt(source[i0].timestamp);
    var hi = indexAt(source[i1].timestamp);
    if (hi < lo) {
      final swap = lo;
      lo = hi;
      hi = swap;
    }
    out.add(
      BrakeEvent(
        startIndex: lo,
        endIndex: hi,
        peakDecelMps2: e.peakDecelMps2,
        avgDecelMps2: e.avgDecelMps2,
        speedDropKmh: e.speedDropKmh,
        startSpeedKmh: e.startSpeedKmh,
        endSpeedKmh: e.endSpeedKmh,
        duration: e.duration,
        hardness: e.hardness,
      ),
    );
  }
  return out;
}
