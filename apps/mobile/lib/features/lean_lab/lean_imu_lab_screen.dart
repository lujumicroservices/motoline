import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lean_lab/lean_imu_lab_sampler.dart';
import '../../core/lean_lab/lean_imu_math.dart';
import '../../core/lean_lab/upright_freeze_controller.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../ride_active/widgets/upright_freeze_panel.dart';

/// Live IMU study bench — every signal the phone can give for lean.
class LeanImuLabScreen extends StatefulWidget {
  const LeanImuLabScreen({super.key});

  @override
  State<LeanImuLabScreen> createState() => _LeanImuLabScreenState();
}

class _LeanImuLabScreenState extends State<LeanImuLabScreen> {
  final LeanImuLabSampler _lab = LeanImuLabSampler();
  late final UprightFreezeController _freeze;

  @override
  void initState() {
    super.initState();
    _lab.addListener(_onTick);
    _lab.start();
    _freeze = UprightFreezeController(_lab.engine)..attach();
    _freeze.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _freeze.removeListener(_onTick);
    _freeze.dispose();
    _lab.removeListener(_onTick);
    _lab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = _lab.latest;

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanImuLabTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
              children: [
                Text(
                  l10n.leanImuLabIntro,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _AttitudeBoard(sample: s, frozen: _lab.hasFreeze),
                const SizedBox(height: 8),
                _PoseEngineBanner(sample: s, frozen: _lab.hasFreeze),
                const SizedBox(height: 12),
                UprightFreezePanel(
                  controller: _freeze,
                  compact: true,
                  showTank: false,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _freeze.busy ? null : _lab.freezeReference,
                        icon: const Icon(Icons.vertical_align_center),
                        label: Text(l10n.leanImuLabFreeze),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _freeze.busy
                            ? null
                            : () {
                                _lab.clearFreeze();
                              },
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.leanImuLabReset),
                      ),
                    ),
                  ],
                ),
                if (_lab.hasFreeze) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.leanImuLabFrozenHint,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.line,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SectionTitle(l10n.leanImuLabAnglesTitle),
                const SizedBox(height: 8),
                _AngleGrid(sample: s),
                const SizedBox(height: 8),
                _Note(l10n.leanImuLabAnglesHelp),
                const SizedBox(height: 18),
                _SectionTitle(l10n.leanImuLabHistoryTitle),
                const SizedBox(height: 8),
                _HistoryChart(history: _lab.history.toList(growable: false)),
                const SizedBox(height: 8),
                _Legend(),
                const SizedBox(height: 18),
                _SectionTitle(l10n.leanImuLabVectorsTitle),
                const SizedBox(height: 8),
                _VectorCard(
                  title: 'Accelerometer (incl. gravity)',
                  hint: 'What production lean uses today. Noisy when riding.',
                  v: s.accel,
                  unit: 'm/s²',
                  expected: 9.8,
                ),
                _VectorCard(
                  title: 'Gravity (low-pass accel)',
                  hint: 'Smoothed down vector. Best static clinometer.',
                  v: s.gravity,
                  unit: 'm/s²',
                  expected: 9.8,
                ),
                _VectorCard(
                  title: 'Linear accel (motion)',
                  hint: 'a − gravity. Braking / bumps. Should be ~0 when still.',
                  v: s.linear,
                  unit: 'm/s²',
                ),
                _VectorCard(
                  title: 'Gyroscope',
                  hint: 'Rotation rate. Integrate for short-term lean; drifts.',
                  v: Vec3(
                    s.gyroRad.x * 180 / math.pi,
                    s.gyroRad.y * 180 / math.pi,
                    s.gyroRad.z * 180 / math.pi,
                  ),
                  unit: '°/s',
                ),
                if (s.mag != null)
                  _VectorCard(
                    title: 'Magnetometer',
                    hint: 'Earth field. Heading / yaw. Distorted by the bike.',
                    v: s.mag!,
                    unit: 'µT',
                  )
                else
                  _Note('Magnetometer: no samples yet (or unavailable).'),
                const SizedBox(height: 8),
                _RatesCard(sample: s),
                const SizedBox(height: 18),
                _SectionTitle(l10n.leanImuLabNextTitle),
                const SizedBox(height: 8),
                _Note(l10n.leanImuLabNextHelp),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.rajdhani(
        color: AppTheme.steel,
        fontSize: 13,
        height: 1.35,
      ),
    );
  }
}

class _AttitudeBoard extends StatelessWidget {
  const _AttitudeBoard({required this.sample, required this.frozen});

  final ImuSample sample;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 168,
            child: CustomPaint(
              painter: _AttitudePainter(sample: sample),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            frozen
                ? 'Vector lean from freeze  ·  up ${sample.upAxis}'
                : 'Bubble = gravity on phone face  ·  up ${sample.upAxis}',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PoseEngineBanner extends StatelessWidget {
  const _PoseEngineBanner({required this.sample, required this.frozen});

  final ImuSample sample;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final conf = sample.trackerConfidence;
    final text = frozen
        ? '${sample.pose.label} · ${sample.winningChannel}'
            '${conf > 0 ? '  ·  conf ${conf.toStringAsFixed(2)}' : ''}'
            '  ·  up ${sample.upAxis}'
        : 'Hold freeze upright  ·  up ${sample.upAxis}  ·  ${sample.pose.label}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: frozen
              ? AppTheme.line.withValues(alpha: 0.5)
              : AppTheme.steel.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.exo2(
          color: frozen ? AppTheme.line : AppTheme.mist,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _AttitudePainter extends CustomPainter {
  _AttitudePainter({required this.sample});

  final ImuSample sample;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 10;
    final ring = Paint()
      ..color = AppTheme.steel.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.5, ring);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);

    // Gravity projected onto phone XZ (screen plane) relative to Y-up.
    final g = sample.gravity.normalized;
    final gx = g.x.clamp(-1.0, 1.0);
    final gz = g.z.clamp(-1.0, 1.0);
    final bubble = Offset(c.dx + gx * r * 0.92, c.dy + gz * r * 0.92);
    canvas.drawCircle(
      bubble,
      10,
      Paint()..color = AppTheme.line,
    );

    // Bike lean wedge (production).
    final leanRad = (sample.bikeLean ?? sample.appLean) * math.pi / 180;
    final leanEnd = Offset(
      c.dx + math.sin(leanRad) * r,
      c.dy - math.cos(leanRad) * r * 0.15,
    );
    canvas.drawLine(
      c,
      leanEnd,
      Paint()
        ..color = AppTheme.signal
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AttitudePainter oldDelegate) =>
      oldDelegate.sample != sample;
}

class _AngleGrid extends StatelessWidget {
  const _AngleGrid({required this.sample});

  final ImuSample sample;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _MetricTile(
          label: 'Bike lean',
          value: sample.bikeLean ?? 0,
          hint: 'sign × vector  (production)',
          color: AppTheme.signal,
        ),
        _MetricTile(
          label: 'Vector lean',
          value: sample.vectorLean,
          hint: '∠ gravity vs freeze',
          color: AppTheme.line,
        ),
        _MetricTile(
          label: 'Old App lean',
          value: sample.appLean,
          hint: 'Legacy closest-axis',
          color: AppTheme.steel,
        ),
        _MetricTile(
          label: 'Roll (X)',
          value: sample.roll,
          hint: 'Left / right',
          color: const Color(0xFF7AB8FF),
        ),
        _MetricTile(
          label: 'Pitch (Z)',
          value: sample.pitch,
          hint: 'Wall / fore-aft',
          color: AppTheme.lineHot,
        ),
        _MetricTile(
          label: 'Tilt |vertical|',
          value: sample.tilt,
          hint: 'Unsigned clinometer',
          color: AppTheme.mist,
        ),
        _MetricTile(
          label: 'Fused roll',
          value: sample.fusedRoll,
          hint: 'Gyro + accel',
          color: const Color(0xFFC084FC),
        ),
        _MetricTile(
          label: 'Fused pitch',
          value: sample.fusedPitch,
          hint: 'Gyro + accel',
          color: const Color(0xFFFB7185),
        ),
        _MetricTile(
          label: 'Gyro |ω|',
          value: sample.gyroDegMag,
          hint: '°/s rotation',
          color: AppTheme.steel,
          unit: '°/s',
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    this.unit = '°',
  });

  final String label;
  final double value;
  final String hint;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
          ),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: GoogleFonts.exo2(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          Text(
            hint,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.history});

  final List<ImuSample> history;

  @override
  Widget build(BuildContext context) {
    if (history.length < 4) {
      return const SizedBox(height: 140);
    }
    final t0 = history.first.at.millisecondsSinceEpoch;
    List<FlSpot> spots(double Function(ImuSample s) y) => [
          for (final s in history)
            FlSpot(
              (s.at.millisecondsSinceEpoch - t0) / 1000.0,
              y(s),
            ),
        ];

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: LineChart(
        LineChartData(
          minY: -70,
          maxY: 70,
          minX: 0,
          maxX: spots((s) => s.bikeLean ?? s.vectorLean).last.x,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppTheme.steel.withValues(alpha: 0.15),
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 35,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(0),
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _bar(spots((s) => s.bikeLean ?? 0), AppTheme.signal, 2.6),
            _bar(spots((s) => s.vectorLean), AppTheme.line, 2.0),
            _bar(spots((s) => s.roll), const Color(0xFF7AB8FF), 1.4),
            _bar(spots((s) => s.pitch), AppTheme.lineHot, 1.4),
            _bar(spots((s) => s.fusedRoll), const Color(0xFFC084FC), 1.4),
          ],
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color, double width) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: width,
      dotData: const FlDotData(show: false),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget chip(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              t,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 11),
            ),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        chip(AppTheme.signal, 'Bike lean'),
        chip(AppTheme.line, 'Vector'),
        chip(const Color(0xFF7AB8FF), 'Roll'),
        chip(AppTheme.lineHot, 'Pitch'),
        chip(const Color(0xFFC084FC), 'Fused roll'),
      ],
    );
  }
}

class _VectorCard extends StatelessWidget {
  const _VectorCard({
    required this.title,
    required this.hint,
    required this.v,
    required this.unit,
    this.expected,
  });

  final String title;
  final String hint;
  final Vec3 v;
  final String unit;
  final double? expected;

  @override
  Widget build(BuildContext context) {
    final mag = v.mag;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            Text(
              hint,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 11),
            ),
            const SizedBox(height: 8),
            _AxisBar(label: 'X', value: v.x, max: expected ?? 20),
            _AxisBar(label: 'Y', value: v.y, max: expected ?? 20),
            _AxisBar(label: 'Z', value: v.z, max: expected ?? 20),
            const SizedBox(height: 4),
            Text(
              '|v| ${mag.toStringAsFixed(2)} $unit'
              '${expected != null ? '   (g≈${expected!.toStringAsFixed(1)})' : ''}',
              style: GoogleFonts.rajdhani(color: AppTheme.mist, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({required this.label, required this.value, required this.max});

  final String label;
  final double value;
  final double max;

  @override
  Widget build(BuildContext context) {
    final t = (value / max).clamp(-1.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(
              label,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final mid = box.maxWidth / 2;
                final w = (t.abs() * mid).clamp(1.0, mid);
                return SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.asphalt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned(
                        left: t >= 0 ? mid : mid - w,
                        width: w,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t >= 0 ? AppTheme.line : AppTheme.signal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: mid - 0.5,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: AppTheme.steel),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              value.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: GoogleFonts.rajdhani(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatesCard extends StatelessWidget {
  const _RatesCard({required this.sample});

  final ImuSample sample;

  @override
  Widget build(BuildContext context) {
    String hz(double v) => v < 0.1 ? '—' : '${v.toStringAsFixed(0)} Hz';
    final heading = sample.heading;
    final baro = sample.pressureHpa;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture rates',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Accel ${hz(sample.accelHz)}   ·   Gyro ${hz(sample.gyroHz)}   ·   '
            'Mag ${hz(sample.magHz)}   ·   Baro ${hz(sample.baroHz)}',
            style: GoogleFonts.rajdhani(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Heading ${heading == null ? '—' : '${heading.toStringAsFixed(0)}° mag'}'
            '   ·   Pressure ${baro == null ? '—' : '${baro.toStringAsFixed(1)} hPa'}',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
