import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/analytics/curva_analysis.dart';
import '../../../core/models/track_point.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

/// Static racing-line snapshot of one corner (no map tiles — list-safe).
class CornerShapeThumb extends StatelessWidget {
  const CornerShapeThumb({
    super.key,
    required this.samples,
    required this.analysis,
    this.height = 152,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ColoredBox(
        color: AppTheme.asphalt,
        child: CustomPaint(
          painter: _CornerShapePainter(
            samples: samples,
            analysis: analysis,
          ),
        ),
      ),
    );
  }
}

class _CornerShapePainter extends CustomPainter {
  _CornerShapePainter({
    required this.samples,
    required this.analysis,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;

  @override
  void paint(Canvas canvas, Size size) {
    final n = samples.length;
    if (n < 2 || size.width < 8 || size.height < 8) return;

    final lo = analysis.mapStartIndex.clamp(0, n - 1);
    final hi = analysis.mapEndIndex.clamp(lo + 1, n - 1);
    final slice = samples.sublist(lo, hi + 1);
    if (slice.length < 2) return;

    var minLat = slice.first.latitude;
    var maxLat = minLat;
    var minLng = slice.first.longitude;
    var maxLng = minLng;
    for (final p in slice) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final mapLat = analysis.mapApexLat;
    final mapLng = analysis.mapApexLng;
    if (mapLat != null && mapLng != null) {
      minLat = math.min(minLat, mapLat);
      maxLat = math.max(maxLat, mapLat);
      minLng = math.min(minLng, mapLng);
      maxLng = math.max(maxLng, mapLng);
    }
    final dLat = math.max(maxLat - minLat, 1e-6);
    final dLng = math.max(maxLng - minLng, 1e-6);
    final pad = 0.18;
    minLat -= dLat * pad;
    maxLat += dLat * pad;
    minLng -= dLng * pad;
    maxLng += dLng * pad;

    final meanLat = (minLat + maxLat) / 2;
    final cosLat = math.cos(meanLat * math.pi / 180).clamp(0.2, 1.0);
    final spanX = (maxLng - minLng) * cosLat;
    final spanY = maxLat - minLat;
    const inset = 16.0;
    final inner = Size(size.width - inset * 2, size.height - inset * 2);
    if (inner.width <= 0 || inner.height <= 0) return;
    final scale = math.min(inner.width / spanX, inner.height / spanY);
    final originX =
        inset + (inner.width - spanX * scale) / 2;
    final originY =
        inset + (inner.height - spanY * scale) / 2;

    Offset projectLatLng(double lat, double lng) {
      final x = originX + (lng - minLng) * cosLat * scale;
      final y = originY + (maxLat - lat) * scale;
      return Offset(x, y);
    }

    Offset project(TrackPoint p) => projectLatLng(p.latitude, p.longitude);

    final speeds = displaySpeedsMps(slice);
    final entryRel = (analysis.entryIndex - lo).clamp(0, slice.length - 1);
    final exitRel = (analysis.exitIndex - lo).clamp(0, slice.length - 1);
    final apexRel = (analysis.displayApexIndex - lo).clamp(0, slice.length - 1);

    final dimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.steel.withValues(alpha: 0.35);

    for (var i = 1; i < slice.length; i++) {
      final inCorner = i > entryRel && i <= exitRel;
      final paint = inCorner
          ? (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = RideVizPalette.speedColor(
              (speeds[i] ?? slice[i].speedMps ?? 0) * 3.6,
            ))
          : dimPaint;
      canvas.drawLine(project(slice[i - 1]), project(slice[i]), paint);
    }

    void pin(Offset at, String letter, Color color) {
      canvas.drawCircle(at, 8, Paint()..color = color);
      canvas.drawCircle(
        at,
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppTheme.mist,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: letter,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppTheme.asphalt,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    pin(
      project(slice[entryRel]),
      'E',
      RideVizPalette.speedColor(analysis.entrySpeedKmh),
    );
    if (analysis.fromMapMatch &&
        analysis.mapApexLat != null &&
        analysis.mapApexLng != null) {
      pin(
        projectLatLng(analysis.mapApexLat!, analysis.mapApexLng!),
        'M',
        AppTheme.lineHot,
      );
      pin(
        project(slice[apexRel]),
        'P',
        AppTheme.line,
      );
    } else {
      pin(
        project(slice[apexRel]),
        'A',
        RideVizPalette.speedColor(analysis.apexSpeedKmh),
      );
    }
    pin(
      project(slice[exitRel]),
      'S',
      RideVizPalette.speedColor(analysis.exitSpeedKmh),
    );
  }

  @override
  bool shouldRepaint(covariant _CornerShapePainter old) =>
      old.samples != samples ||
      old.analysis.entryIndex != analysis.entryIndex ||
      old.analysis.exitIndex != analysis.exitIndex ||
      old.analysis.mapApexLat != analysis.mapApexLat ||
      old.analysis.fromMapMatch != analysis.fromMapMatch;
}
