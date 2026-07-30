import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/track_point.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import 'pilot_line_map.dart';
import 'widgets/motorcycle_lean_gauge.dart';
import 'widgets/ride_profile_chart.dart';

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(rideProvider(rideId));
    final pointsAsync = ref.watch(ridePointsProvider(rideId));

    return Scaffold(
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ride) {
          if (ride == null) {
            return const Center(child: Text('Ride not found'));
          }
          return pointsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (points) => _RideDashboard(
              rideId: rideId,
              analytics: RideAnalytics(ride: ride, points: points),
            ),
          );
        },
      ),
    );
  }
}

class _RideDashboard extends StatefulWidget {
  const _RideDashboard({
    required this.rideId,
    required this.analytics,
  });

  final String rideId;
  final RideAnalytics analytics;

  @override
  State<_RideDashboard> createState() => _RideDashboardState();
}

class _RideDashboardState extends State<_RideDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late int _scrubIndex;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    final samples = widget.analytics.samples;
    _scrubIndex = samples.isEmpty ? 0 : samples.length ~/ 2;
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _setScrubIndex(int index) {
    final max = widget.analytics.samples.length - 1;
    if (max < 0) return;
    setState(() => _scrubIndex = index.clamp(0, max));
  }

  void _setScrubSeconds(double seconds) {
    _setScrubIndex(widget.analytics.indexForSeconds(seconds));
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.analytics;
    final ride = a.ride;
    final hasSamples = a.samples.isNotEmpty;
    final scrubSeconds = hasSamples ? a.secondsForIndex(_scrubIndex) : 0.0;
    final scrubPoint = hasSamples ? a.samples[_scrubIndex] : null;
    final scrubLean = hasSamples ? a.relativeLeanAt(_scrubIndex) : 0.0;

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.asphalt,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                title: Text(
                  'Ride lab',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity:
                      CurvedAnimation(parent: _intro, curve: Curves.easeOut),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CornerIQ',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.4,
                            color: AppTheme.line,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat('EEE · MMM d · HH:mm')
                              .format(ride.startedAt),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Scrub any moment. Map and graphs stay locked together.',
                          style: GoogleFonts.outfit(
                            color: AppTheme.steel,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _ScoreHero(
                          score: a.lineScore,
                          label: a.lineScoreLabel,
                          animation: _intro,
                        ),
                        const SizedBox(height: 20),
                        _MetricGrid(analytics: a),
                        const SizedBox(height: 28),
                        if (a.leanSides.sampleCount > 0) ...[
                          MotorcycleLeanGauge(
                            leanDegrees: scrubLean,
                            maxLeftDegrees: a.maxLeanLeft,
                            maxRightDegrees: a.maxLeanRight,
                            neutralLabel:
                                'At playhead · neutral offset ${a.neutralLeanDegrees.toStringAsFixed(0)}°',
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '0° is inferred upright (works with phone in pocket). '
                            'Teal = left bank · orange = right bank.',
                            style: GoogleFonts.outfit(
                              color: AppTheme.steel,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        Text(
                          'The line you took',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teal slower · amber mid · orange faster. Amber marker = scrubbed moment.',
                          style: GoogleFonts.outfit(
                            color: AppTheme.steel,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 280,
                          child: PilotLineMap(
                            points: a.samples,
                            scrubIndex: hasSamples ? _scrubIndex : null,
                          ),
                        ),
                        const SizedBox(height: 32),
                        RideProfileChart(
                          title: 'Speed profile',
                          subtitle:
                              'Tap or drag the chart — playhead syncs map + lean',
                          series: a.speedSeries,
                          lineColor: AppTheme.lineHot,
                          unit: 'km/h',
                          baselineZero: true,
                          minY: 0,
                          selectedSeconds: scrubSeconds,
                          onSelectSeconds: _setScrubSeconds,
                        ),
                        const SizedBox(height: 32),
                        if (a.leanSeries.isNotEmpty) ...[
                          RideProfileChart(
                            title: 'Lean left / right',
                            subtitle:
                                'Relative bike lean vs inferred 0°. Negative = left · positive = right',
                            series: a.leanSeries,
                            lineColor: AppTheme.line,
                            unit: '°',
                            baselineZero: true,
                            selectedSeconds: scrubSeconds,
                            onSelectSeconds: _setScrubSeconds,
                          ),
                          const SizedBox(height: 32),
                        ],
                        if (a.accuracySeries.isNotEmpty) ...[
                          RideProfileChart(
                            title: 'GPS precision',
                            subtitle:
                                'Horizontal accuracy in meters (lower is better)',
                            series: a.accuracySeries,
                            lineColor: AppTheme.signal,
                            unit: 'm',
                            baselineZero: true,
                            minY: 0,
                            selectedSeconds: scrubSeconds,
                            onSelectSeconds: _setScrubSeconds,
                          ),
                          const SizedBox(height: 32),
                        ],
                        _PrecisionPanel(analytics: a),
                        const SizedBox(height: 28),
                        _InsightStrip(analytics: a),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasSamples)
          Material(
            color: AppTheme.asphalt,
            elevation: 12,
            shadowColor: Colors.black54,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _TimeScrubber(
                  seconds: scrubSeconds,
                  totalSeconds: a.totalSeconds,
                  point: scrubPoint!,
                  leanDegrees: scrubLean,
                  index: _scrubIndex,
                  totalPoints: a.samples.length,
                  onChanged: _setScrubSeconds,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeScrubber extends StatelessWidget {
  const _TimeScrubber({
    required this.seconds,
    required this.totalSeconds,
    required this.point,
    required this.leanDegrees,
    required this.index,
    required this.totalPoints,
    required this.onChanged,
  });

  final double seconds;
  final double totalSeconds;
  final TrackPoint point;
  final double leanDegrees;
  final int index;
  final int totalPoints;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final speed = point.speedKmh;
    final side = leanDegrees < -1
        ? 'L'
        : leanDegrees > 1
            ? 'R'
            : '·';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.lineHot.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PLAYHEAD',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lineHot,
                ),
              ),
              const Spacer(),
              Text(
                _fmt(seconds),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Point ${index + 1}/$totalPoints  ·  '
            '${speed == null ? "--" : "${speed.toStringAsFixed(0)} km/h"}  ·  '
            'lean ${leanDegrees.abs().toStringAsFixed(0)}° $side  ·  '
            'GPS ${point.accuracyMeters?.toStringAsFixed(1) ?? "--"} m',
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.lineHot,
              inactiveTrackColor: AppTheme.mist.withValues(alpha: 0.12),
              thumbColor: AppTheme.mist,
              overlayColor: AppTheme.lineHot.withValues(alpha: 0.15),
              trackHeight: 3,
            ),
            child: Slider(
              value: seconds.clamp(0, totalSeconds <= 0 ? 0 : totalSeconds),
              min: 0,
              max: totalSeconds <= 0 ? 1 : totalSeconds,
              onChanged: totalSeconds <= 0 ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double s) {
    final total = s.round();
    final m = total ~/ 60;
    final r = total % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({
    required this.score,
    required this.label,
    required this.animation,
  });

  final int score;
  final String label;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A3036),
                Color(0xFF1E2226),
                Color(0xFF171A1D),
              ],
            ),
            border: Border.all(color: AppTheme.line.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100 * t,
                      strokeWidth: 7,
                      backgroundColor: AppTheme.mist.withValues(alpha: 0.08),
                      color: AppTheme.line,
                    ),
                    Text(
                      '${(score * t).round()}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LINE QUALITY',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.steel,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From GPS density, accuracy, and coverage.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.steel,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.analytics});

  final RideAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigStat(
                label: 'Distance',
                value: a.distanceKm.toStringAsFixed(2),
                unit: 'km',
                accent: AppTheme.line,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStat(
                label: 'Duration',
                value: formatDurationLong(a.duration),
                unit: '',
                accent: AppTheme.mist,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BigStat(
                label: 'Max speed',
                value: a.maxSpeedKmh == null
                    ? '--'
                    : a.maxSpeedKmh!.toStringAsFixed(0),
                unit: 'km/h',
                accent: AppTheme.lineHot,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStat(
                label: 'Max L / R',
                value: a.leanSides.sampleCount == 0
                    ? '--'
                    : '${a.maxLeanLeft.toStringAsFixed(0)}/${a.maxLeanRight.toStringAsFixed(0)}',
                unit: '°',
                accent: AppTheme.signal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: AppTheme.steel,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PrecisionPanel extends StatelessWidget {
  const _PrecisionPanel({required this.analytics});

  final RideAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Capture precision',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How cleanly this ride was measured on your phone.',
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniPill(
                label: 'Points',
                value: '${a.samples.length}',
              ),
              _MiniPill(
                label: 'Rate',
                value: a.sampleRateHz == null
                    ? '--'
                    : '${a.sampleRateHz!.toStringAsFixed(1)} Hz',
              ),
              _MiniPill(
                label: 'Avg GPS',
                value: a.avgGpsAccuracyM == null
                    ? '--'
                    : '${a.avgGpsAccuracyM!.toStringAsFixed(1)} m',
              ),
              _MiniPill(
                label: 'Best GPS',
                value: a.bestGpsAccuracyM == null
                    ? '--'
                    : '${a.bestGpsAccuracyM!.toStringAsFixed(1)} m',
              ),
              _MiniPill(
                label: 'Moving avg',
                value: a.avgMovingSpeedKmh == null
                    ? '--'
                    : '${a.avgMovingSpeedKmh!.toStringAsFixed(0)} km/h',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.asphalt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              letterSpacing: 0.9,
              color: AppTheme.steel,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightStrip extends StatelessWidget {
  const _InsightStrip({required this.analytics});

  final RideAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final insights = <String>[];

    if (a.sampleRateHz != null && a.sampleRateHz! >= 2) {
      insights.add(
        'Dense capture at ${a.sampleRateHz!.toStringAsFixed(1)} Hz — glorieta loops and lane changes stay visible.',
      );
    } else if (a.sampleRateHz != null && a.sampleRateHz! < 0.5) {
      insights.add(
        'Sparse GPS this ride. Keep the recording notification on and avoid battery restrictions.',
      );
    }

    if (a.avgGpsAccuracyM != null && a.avgGpsAccuracyM! <= 6) {
      insights.add(
        'GPS lock averaged ${a.avgGpsAccuracyM!.toStringAsFixed(1)} m — strong enough for a trustworthy pilot line.',
      );
    }

    if (a.maxLeanLeft >= 15 || a.maxLeanRight >= 15) {
      insights.add(
        'Peak banks ${a.maxLeanLeft.toStringAsFixed(0)}° left / '
        '${a.maxLeanRight.toStringAsFixed(0)}° right after removing pocket neutral '
        '(${a.neutralLeanDegrees.toStringAsFixed(0)}° offset).',
      );
    } else if (a.maxLeanAbs != null && a.maxLeanAbs! >= 25) {
      insights.add(
        'Peak lean hit ${a.maxLeanAbs!.toStringAsFixed(0)}°. Mount orientation affects this reading — keep the phone fixed.',
      );
    }

    if (a.maxSpeedKmh != null && a.maxSpeedKmh! >= 40) {
      insights.add(
        'Top speed ${a.maxSpeedKmh!.toStringAsFixed(0)} km/h recorded cleanly on the speed profile.',
      );
    }

    if (insights.isEmpty) {
      insights.add(
        'Ride saved offline. Open this lab anytime to scrub your line and profiles.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coach notes',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < insights.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.mist.withValues(alpha: 0.08)),
              color: AppTheme.asphaltElevated.withValues(alpha: 0.65),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    color: AppTheme.line,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insights[i],
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      height: 1.45,
                      color: AppTheme.mist,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
