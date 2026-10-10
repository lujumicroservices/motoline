import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../theme/offroad_theme.dart';
import '../circuit_model.dart';

/// Orange corridor (outer minus inner) with the centerline painted per sector,
/// drawn like the Métrica circuit page. [highlight] dims every other sector.
class CircuitSilhouette extends StatelessWidget {
  const CircuitSilhouette({
    super.key,
    required this.circuit,
    this.highlight,
    this.showSectors = true,
    this.padding = 8,
  });

  final Circuit circuit;
  final int? highlight;
  final bool showSectors;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SilhouettePainter(circuit, highlight, showSectors, padding),
      size: Size.infinite,
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.c, this.highlight, this.showSectors, this.pad);

  final Circuit c;
  final int? highlight;
  final bool showSectors;
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.cos(c.anchor.latitude * math.pi / 180);
    Offset raw(LatLng p) => Offset(p.longitude * k, -p.latitude);
    final all = [...c.outer, ...c.inner].map(raw).toList();
    var minX = all.first.dx, maxX = minX, minY = all.first.dy, maxY = minY;
    for (final o in all) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }
    final scale = math.min(
      (size.width - 2 * pad) / (maxX - minX),
      (size.height - 2 * pad) / (maxY - minY),
    );
    final ox = (size.width - (maxX - minX) * scale) / 2;
    final oy = (size.height - (maxY - minY) * scale) / 2;
    Offset map(LatLng p) {
      final r = raw(p);
      return Offset(ox + (r.dx - minX) * scale, oy + (r.dy - minY) * scale);
    }

    Path ring(List<LatLng> pts) =>
        Path()..addPolygon(pts.map(map).toList(), true);

    final corridor = Path.combine(
      PathOperation.difference,
      ring(c.outer),
      ring(c.inner),
    );
    canvas.drawPath(
      corridor,
      Paint()
        ..color = OffroadTheme.track.withValues(
          alpha: highlight == null ? 1 : 0.55,
        ),
    );
    final edge = Paint()
      ..color = OffroadTheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(ring(c.outer), edge);
    canvas.drawPath(ring(c.inner), edge);

    if (!showSectors) return;
    final lines = c.sectorLines();
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].length < 2) continue;
      final dim = highlight != null && highlight != i;
      final path = Path()..addPolygon(lines[i].map(map).toList(), false);
      canvas.drawPath(
        path,
        Paint()
          ..color = OffroadTheme.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = dim ? 2 : 4.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = OffroadTheme.sector(i).withValues(alpha: dim ? 0.35 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = dim ? 1.2 : 2.6
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final g in c.gates) {
      final a = map(g.a), b = map(g.b);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = OffroadTheme.outline
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = g.kind == 0 ? Colors.white : OffroadTheme.textFaint
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) =>
      old.c != c || old.highlight != highlight || old.showSectors != showSectors;
}
