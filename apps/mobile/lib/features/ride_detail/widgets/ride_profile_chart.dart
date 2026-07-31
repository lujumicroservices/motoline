import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/analytics/ride_analytics.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';

class RideProfileChart extends StatelessWidget {
  const RideProfileChart({
    super.key,
    required this.title,
    required this.subtitle,
    required this.series,
    required this.lineColor,
    required this.unit,
    this.baselineZero = false,
    this.minY,
    this.maxY,
    this.selectedSeconds,
    this.onSelectSeconds,
    this.colorForValue,
  });

  final String title;
  final String subtitle;
  final List<TimedValue> series;
  final Color lineColor;
  final String unit;
  final bool baselineZero;
  final double? minY;
  final double? maxY;

  /// Vertical playhead position in ride seconds.
  final double? selectedSeconds;

  /// Called when user taps/drags the chart to pick a time.
  final ValueChanged<double>? onSelectSeconds;

  /// When set, each segment is colored from this mapping (speed / lean scales).
  final Color Function(double value)? colorForValue;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) {
      return const SizedBox.shrink();
    }

    final values = series.map((e) => e.value).toList();
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (baselineZero) {
      lo = lo < 0 ? lo : 0;
    }
    if (minY != null) lo = minY!;
    if (maxY != null) hi = maxY!;
    if ((hi - lo).abs() < 0.01) {
      hi = lo + 1;
    }
    final pad = (hi - lo) * 0.12;
    final minChartY = lo - pad;
    final maxChartY = hi + pad;

    final spots = [
      for (final s in series) FlSpot(s.seconds, s.value),
    ];

    final scrubX = selectedSeconds?.clamp(spots.first.x, spots.last.x);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.exo2(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: minChartY,
              maxY: maxChartY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: ((hi - lo) / 3).clamp(1, 50),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppTheme.mist.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(0),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: _bottomInterval(series.last.seconds),
                    getTitlesWidget: (value, meta) {
                      if (value < 0) return const SizedBox.shrink();
                      return Text(
                        _formatAxisTime(value),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: onSelectSeconds != null,
                handleBuiltInTouches: true,
                touchCallback: (event, response) {
                  if (onSelectSeconds == null) return;
                  if (!event.isInterestedForInteractions) return;
                  final spot = response?.lineBarSpots?.isNotEmpty == true
                      ? response!.lineBarSpots!.first
                      : null;
                  if (spot != null) {
                    onSelectSeconds!(spot.x);
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${t.y.toStringAsFixed(1)} $unit\n${_formatAxisTime(t.x)}',
                        GoogleFonts.exo2(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              extraLinesData: scrubX == null
                  ? null
                  : ExtraLinesData(
                      verticalLines: [
                        VerticalLine(
                          x: scrubX,
                          color: AppTheme.lineHot,
                          strokeWidth: 2,
                          dashArray: const [6, 4],
                        ),
                      ],
                    ),
              lineBarsData: [
                ..._lineBars(spots, scrubX),
                if (baselineZero)
                  LineChartBarData(
                    spots: [
                      FlSpot(spots.first.x, 0),
                      FlSpot(spots.last.x, 0),
                    ],
                    color: AppTheme.steel.withValues(alpha: 0.35),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _lineBars(List<FlSpot> spots, double? scrubX) {
    final colorFn = colorForValue;
    if (colorFn == null) {
      return [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: lineColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: _dotData(scrubX, lineColor),
          belowBarData: BarAreaData(
            show: true,
            color: lineColor.withValues(alpha: 0.14),
          ),
        ),
      ];
    }

    // Segment so each stretch uses the value→color scale (speed / lean).
    final bars = <LineChartBarData>[];
    for (var i = 1; i < spots.length; i++) {
      final a = spots[i - 1];
      final b = spots[i];
      final mid = (a.y + b.y) / 2;
      final color = colorFn(mid);
      bars.add(
        LineChartBarData(
          spots: [a, b],
          isCurved: false,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: _dotData(scrubX, color),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.12),
          ),
        ),
      );
    }
    return bars;
  }

  FlDotData _dotData(double? scrubX, Color stroke) {
    return FlDotData(
      show: scrubX != null,
      checkToShowDot: (spot, bar) {
        if (scrubX == null) return false;
        return (spot.x - scrubX).abs() < 0.35;
      },
      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
        radius: 5,
        color: AppTheme.mist,
        strokeWidth: 2,
        strokeColor: stroke,
      ),
    );
  }

  double _bottomInterval(double totalSeconds) {
    if (totalSeconds <= 60) return 15;
    if (totalSeconds <= 300) return 60;
    if (totalSeconds <= 900) return 120;
    return 300;
  }

  String _formatAxisTime(double seconds) {
    final s = seconds.round();
    final m = s ~/ 60;
    final r = s % 60;
    if (m == 0) return '${r}s';
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

/// Convenience: speed series with shared blue→red scale.
class SpeedProfileChart extends StatelessWidget {
  const SpeedProfileChart({
    super.key,
    required this.series,
    this.selectedSeconds,
    this.onSelectSeconds,
    this.subtitle,
  });

  final List<TimedValue> series;
  final double? selectedSeconds;
  final ValueChanged<double>? onSelectSeconds;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RideProfileChart(
      title: l10n.speedProfile,
      subtitle: subtitle ?? l10n.chartSpeedSub,
      series: series,
      lineColor: RideVizPalette.speedMid,
      unit: l10n.kmh,
      baselineZero: true,
      minY: 0,
      selectedSeconds: selectedSeconds,
      onSelectSeconds: onSelectSeconds,
      colorForValue: RideVizPalette.speedColor,
    );
  }
}

/// Convenience: lean series with cyan left / amber right.
class LeanProfileChart extends StatelessWidget {
  const LeanProfileChart({
    super.key,
    required this.series,
    this.selectedSeconds,
    this.onSelectSeconds,
    this.subtitle,
  });

  final List<TimedValue> series;
  final double? selectedSeconds;
  final ValueChanged<double>? onSelectSeconds;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RideProfileChart(
      title: l10n.leanProfile,
      subtitle: subtitle ?? l10n.leanHelp,
      series: series,
      lineColor: RideVizPalette.leanLeft,
      unit: '°',
      baselineZero: true,
      selectedSeconds: selectedSeconds,
      onSelectSeconds: onSelectSeconds,
      colorForValue: RideVizPalette.leanColor,
    );
  }
}
