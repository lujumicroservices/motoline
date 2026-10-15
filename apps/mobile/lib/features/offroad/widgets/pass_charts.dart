import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/offroad_theme.dart';
import '../pass_channels.dart';
import '../session_model.dart';

/// Row whose ridden distance is closest to [metres].
int traceIndexAtDistance(PassTrace t, double metres) {
  var lo = 0, hi = t.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (t.dist[mid] < metres) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo > 0 && (metres - t.dist[lo - 1]).abs() < (t.dist[lo] - metres).abs()) {
    return lo - 1;
  }
  return lo;
}

/// One channel against ridden distance, line coloured with the map scale,
/// braking zones shaded. Drag or tap to move [cursor].
class ChannelChart extends StatelessWidget {
  const ChannelChart({
    super.key,
    required this.trace,
    required this.channel,
    this.brakes = const [],
    this.cursor,
    this.onScrub,
    this.compact = false,
  });

  final PassTrace trace;
  final TraceChannel channel;
  final List<(int, int)> brakes;
  final int? cursor;
  final ValueChanged<int>? onScrub;
  final bool compact;

  static const _maxSpots = 600;

  @override
  Widget build(BuildContext context) {
    final t = trace;
    final range = channel.range(t);
    final step = math.max(1, (t.length / _maxSpots).ceil());
    final spots = <FlSpot>[
      for (var i = 0; i < t.length; i += step)
        FlSpot(t.dist[i], channel.value(t, i)),
    ];
    final minX = t.dist.first;
    final maxX = math.max(t.dist.last, minX + 1);
    var minY = spots.map((s) => s.y).reduce(math.min);
    var maxY = spots.map((s) => s.y).reduce(math.max);
    if (channel.diverging) {
      final m = math.max(minY.abs(), maxY.abs());
      minY = -m;
      maxY = m;
    } else if (channel != TraceChannel.elevation) {
      minY = 0;
    }
    final pad = (maxY - minY) * 0.08 + 1e-3;

    const stops = 96;
    final colors = <Color>[];
    final positions = <double>[];
    for (var k = 0; k < stops; k++) {
      final x = minX + (maxX - minX) * k / (stops - 1);
      final i = traceIndexAtDistance(t, x);
      colors.add(channel.color(channel.value(t, i), range));
      positions.add(k / (stops - 1));
    }

    void scrub(FlTouchEvent e, LineTouchResponse? r) {
      final cb = onScrub;
      final c = r?.touchChartCoordinate;
      if (cb == null || c == null || !e.isInterestedForInteractions) return;
      cb(traceIndexAtDistance(t, c.dx.clamp(minX, maxX)));
    }

    final faint = TextStyle(
      fontSize: compact ? 10 : 11,
      color: OffroadTheme.textFaint,
    );
    return LineChart(
      duration: Duration.zero,
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY - pad,
        maxY: maxY + pad,
        clipData: const FlClipData.all(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            barWidth: compact ? 2 : 2.6,
            isCurved: false,
            dotData: const FlDotData(show: false),
            gradient: LinearGradient(colors: colors, stops: positions),
            gradientArea: LineChartGradientArea.wholeChart,
          ),
        ],
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            for (final (a, b) in brakes)
              VerticalRangeAnnotation(
                x1: t.dist[a],
                x2: math.max(t.dist[b], t.dist[a] + 2),
                color: const Color(0xFFFF3B30).withValues(alpha: 0.22),
              ),
          ],
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (channel.diverging)
              HorizontalLine(y: 0, color: OffroadTheme.panelBorder, strokeWidth: 1),
          ],
          verticalLines: [
            if (cursor != null)
              VerticalLine(
                x: t.dist[cursor!.clamp(0, t.length - 1)],
                color: Colors.white,
                strokeWidth: 1.5,
              ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFF242424), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: compact ? 34 : 40,
              getTitlesWidget: (v, meta) =>
                  v == meta.min || v == meta.max
                      ? const SizedBox.shrink()
                      : Text(channel.format(v), style: faint),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 22,
              interval: 200,
              getTitlesWidget: (v, meta) =>
                  v == meta.min || v == meta.max
                      ? const SizedBox.shrink()
                      : Text('${v.toStringAsFixed(0)} m', style: faint),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false,
          touchCallback: scrub,
        ),
      ),
    );
  }
}

/// Friction-circle (G-G) plot: lateral g on x, braking / throttle on y,
/// dots coloured by sector. A fuller, rounder cloud means more grip used.
class GgDiagram extends StatelessWidget {
  const GgDiagram({super.key, required this.trace, this.cursor, this.labels});

  final PassTrace trace;
  final int? cursor;

  /// Brake, throttle, left, right axis captions.
  final (String, String, String, String)? labels;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _GgPainter(trace, cursor, labels)),
    );
  }
}

class _GgPainter extends CustomPainter {
  _GgPainter(this.t, this.cursor, this.labels);

  final PassTrace t;
  final int? cursor;
  final (String, String, String, String)? labels;

  @override
  void paint(Canvas canvas, Size size) {
    var peak = 0.1;
    for (var i = 0; i < t.length; i++) {
      peak = math.max(peak, math.max(t.latG[i].abs(), t.longG[i].abs()));
    }
    final maxG = (peak / 0.1).ceil() * 0.1;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 18;
    Offset at(int i) =>
        c + Offset(t.latG[i] / maxG * r, -t.longG[i] / maxG * r);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF2E2E2E)
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var g = 0.1; g <= maxG + 1e-6; g += 0.1) {
      canvas.drawCircle(c, g / maxG * r, ring);
      tp
        ..text = TextSpan(
          text: '${g.toStringAsFixed(1)} g',
          style: const TextStyle(fontSize: 9, color: OffroadTheme.textFaint),
        )
        ..layout();
      tp.paint(canvas, c + Offset(g / maxG * r * 0.71 + 2, -g / maxG * r * 0.71 - 10));
    }
    canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), ring);
    canvas.drawLine(c - Offset(0, r), c + Offset(0, r), ring);

    for (var i = 0; i < t.length; i++) {
      if (t.kmh[i] < 3) continue;
      canvas.drawCircle(
        at(i),
        1.8,
        Paint()..color = OffroadTheme.sector(t.sector[i]).withValues(alpha: 0.55),
      );
    }

    final cur = cursor;
    if (cur != null && cur >= 0 && cur < t.length) {
      canvas.drawCircle(at(cur), 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        at(cur),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black,
      );
    }

    final l = labels;
    if (l == null) return;
    /// [align]: -1 left edge at [o], 0 centred, 1 right edge at [o].
    void label(String s, Offset o, {int align = 0}) {
      tp
        ..text = TextSpan(
          text: s,
          style: OffroadTheme.label(color: OffroadTheme.textMuted).copyWith(fontSize: 10),
        )
        ..layout();
      final dx = switch (align) { -1 => 0.0, 1 => tp.width, _ => tp.width / 2 };
      tp.paint(canvas, o - Offset(dx, tp.height / 2));
    }

    label(l.$2, c - Offset(0, r + 9));
    label(l.$1, c + Offset(0, r + 9));
    label(l.$3, Offset(2, c.dy - 10), align: -1);
    label(l.$4, Offset(size.width - 2, c.dy - 10), align: 1);
  }

  @override
  bool shouldRepaint(covariant _GgPainter old) =>
      old.t != t || old.cursor != cursor;
}
