import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../pass_channels.dart';
import '../session_model.dart';

/// flutter_map layer that paints a pass coloured per segment by [channel].
///
/// flutter_map's own polyline gradient runs straight from the first to the
/// last point, which is meaningless on a closed lap, hence the custom painter.
class TraceHeatLayer extends StatelessWidget {
  const TraceHeatLayer({
    super.key,
    required this.trace,
    required this.channel,
    this.brakes = const [],
    this.ghost,
    this.window,
  });

  final PassTrace trace;
  final TraceChannel channel;

  /// Row ranges drawn with a red halo under the line.
  final List<(int, int)> brakes;

  /// Reference pass drawn thin and white underneath.
  final PassTrace? ghost;

  /// Rows `(from, to)` to emphasise; the rest is dimmed.
  final (int, int)? window;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _HeatPainter(
            camera: camera,
            trace: trace,
            channel: channel,
            range: channel.range(trace),
            brakes: brakes,
            ghost: ghost,
            window: window,
          ),
        ),
      ),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({
    required this.camera,
    required this.trace,
    required this.channel,
    required this.range,
    required this.brakes,
    required this.ghost,
    required this.window,
  });

  final MapCamera camera;
  final PassTrace trace;
  final TraceChannel channel;
  final (double, double) range;
  final List<(int, int)> brakes;
  final PassTrace? ghost;
  final (int, int)? window;

  static const _buckets = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final w = ((camera.zoom - 15) * 1.6).clamp(3.0, 10.0);
    final pts = [for (final p in trace.points) camera.latLngToScreenOffset(p)];

    final g = ghost;
    if (g != null) {
      final path = Path()
        ..addPolygon(
          [for (final p in g.points) camera.latLngToScreenOffset(p)],
          false,
        );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, w * 0.45)
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    canvas.drawPath(
      Path()..addPolygon(pts, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w + 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.7),
    );

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w + 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFF3B30).withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final (a, b) in brakes) {
      if (b <= a) continue;
      canvas.drawPath(Path()..addPolygon(pts.sublist(a, b + 1), false), halo);
    }

    // Segments bucketed by colour: one path per bucket keeps draw calls low.
    final paths = List.generate(_buckets, (_) => Path());
    final dimPaths = List.generate(_buckets, (_) => Path());
    final (lo, hi) = range;
    for (var i = 1; i < pts.length; i++) {
      final v = channel.value(trace, i);
      final k = (((v - lo) / (hi - lo)) * (_buckets - 1))
          .round()
          .clamp(0, _buckets - 1);
      final win = window;
      final dim = win != null && (i < win.$1 || i > win.$2);
      (dim ? dimPaths : paths)[k]
        ..moveTo(pts[i - 1].dx, pts[i - 1].dy)
        ..lineTo(pts[i].dx, pts[i].dy);
    }
    for (var k = 0; k < _buckets; k++) {
      final v = lo + (hi - lo) * k / (_buckets - 1);
      final color = channel.color(v, range);
      canvas.drawPath(
        dimPaths[k],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.7
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.3),
      );
      canvas.drawPath(
        paths[k],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) =>
      old.camera != camera ||
      old.trace != trace ||
      old.channel != channel ||
      old.ghost != ghost ||
      old.window != window ||
      old.brakes != brakes;
}

/// Horizontal colour bar with min / max labels for [channel].
class ChannelLegend extends StatelessWidget {
  const ChannelLegend({
    super.key,
    required this.channel,
    required this.range,
    this.width = 180,
  });

  final TraceChannel channel;
  final (double, double) range;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (lo, hi) = range;
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      fontFeatures: [ui.FontFeature.tabularFigures()],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: width,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(colors: channel.legend()),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: width,
          child: Row(
            children: [
              Text('${channel.format(lo)} ${channel.unit}', style: style),
              const Spacer(),
              if (channel.diverging) const Text('0', style: style),
              if (channel.diverging) const Spacer(),
              Text('${channel.format(hi)} ${channel.unit}', style: style),
            ],
          ),
        ),
      ],
    );
  }
}
