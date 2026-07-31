import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

/// Builds speed / road-kind styled track polylines with consecutive same-style
/// edges merged. Avoids one Polyline per GPS edge (thousands of objects), which
/// freezes pan/zoom on longer rides.
List<Polyline> buildMergedStyledPolylines({
  required List<TrackPoint> segment,
  required int indexOffset,
  required List<(RoadKind kind, TurnSide side)?> kindByIndex,
  required bool showRoadKindContrast,
  required bool showSpeedColors,
  /// Quantize speed so nearby km/h share a color and merge into longer runs.
  double speedBucketKmh = 5,
}) {
  if (segment.length < 2) return const [];

  final result = <Polyline>[];
  List<LatLng>? run;
  Color? runColor;
  double? runWidth;

  void flush() {
    final pts = run;
    final color = runColor;
    final width = runWidth;
    if (pts == null || color == null || width == null || pts.length < 2) {
      run = null;
      return;
    }
    result.add(Polyline(points: pts, color: color, strokeWidth: width));
    run = null;
  }

  for (var i = 1; i < segment.length; i++) {
    final a = segment[i - 1];
    final b = segment[i];
    final absIndex = indexOffset + i;
    final style = strokeStyleForTrackIndex(
      absIndex: absIndex,
      point: b,
      kindByIndex: kindByIndex,
      showRoadKindContrast: showRoadKindContrast,
      showSpeedColors: showSpeedColors,
      speedBucketKmh: speedBucketKmh,
    );

    final aLatLng = LatLng(a.latitude, a.longitude);
    final bLatLng = LatLng(b.latitude, b.longitude);

    if (run != null && runColor == style.$1 && runWidth == style.$2) {
      run!.add(bLatLng);
    } else {
      flush();
      run = [aLatLng, bLatLng];
      runColor = style.$1;
      runWidth = style.$2;
    }
  }
  flush();
  return result;
}

(Color, double) strokeStyleForTrackIndex({
  required int absIndex,
  required TrackPoint point,
  required List<(RoadKind kind, TurnSide side)?> kindByIndex,
  required bool showRoadKindContrast,
  required bool showSpeedColors,
  double speedBucketKmh = 5,
}) {
  if (showRoadKindContrast &&
      absIndex >= 0 &&
      absIndex < kindByIndex.length) {
    final kind = kindByIndex[absIndex];
    if (kind != null) {
      if (kind.$1 == RoadKind.recta) {
        return (RideVizPalette.roadRecta.withValues(alpha: 0.75), 3.5);
      }
      final color = switch (kind.$2) {
        TurnSide.izquierda => RideVizPalette.roadCurvaLeft,
        TurnSide.derecha => RideVizPalette.roadCurvaRight,
        TurnSide.none => RideVizPalette.roadCurva,
      };
      return (color, 7);
    }
  }

  if (showSpeedColors) {
    final raw = point.speedKmh ?? 0;
    final bucket = speedBucketKmh <= 0
        ? raw
        : (raw / speedBucketKmh).round() * speedBucketKmh;
    return (RideVizPalette.speedColor(bucket.toDouble()), 5);
  }

  return (AppTheme.mist.withValues(alpha: 0.85), 4);
}

List<(RoadKind kind, TurnSide side)?> kindByIndexFromStretches({
  required int length,
  required List<RoadStretch> stretches,
}) {
  final out = List<(RoadKind, TurnSide)?>.filled(length, null);
  for (final s in stretches) {
    final lo = s.startIndex.clamp(0, length - 1);
    final hi = s.endIndex.clamp(lo, length - 1);
    for (var i = lo; i <= hi; i++) {
      out[i] = (s.kind, s.side);
    }
  }
  return out;
}
