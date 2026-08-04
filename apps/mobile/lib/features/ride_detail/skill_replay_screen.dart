import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/curva_analysis.dart';
import '../../core/analytics/lean_neutral.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import 'pilot_line_map.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/motorcycle_lean_gauge.dart';

/// Live replay of a corner: lean, brake intensity, speed + map playhead.
class SkillReplayScreen extends StatefulWidget {
  const SkillReplayScreen({
    super.key,
    required this.samples,
    required this.analysis,
    required this.neutralLeanDegrees,
    this.brakeEvents = const [],
    this.title,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;
  final double neutralLeanDegrees;
  final List<BrakeEvent> brakeEvents;
  final String? title;

  @override
  State<SkillReplayScreen> createState() => _SkillReplayScreenState();
}

class _SkillReplayScreenState extends State<SkillReplayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final int _lo;
  late final int _hi;
  late final List<TrackPoint> _slice;
  double _rate = 1;
  bool _loop = true;

  @override
  void initState() {
    super.initState();
    final n = widget.samples.length;
    _lo = widget.analysis.mapStartIndex.clamp(0, n - 1);
    _hi = widget.analysis.mapEndIndex.clamp(_lo, n - 1);
    _slice = widget.samples.sublist(_lo, _hi + 1);
    final realMs = _slice.length < 2
        ? 2000
        : _slice.last.timestamp
            .difference(_slice.first.timestamp)
            .inMilliseconds
            .clamp(800, 45000);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (realMs / _rate).round()),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && _loop && mounted) {
          _ctrl.forward(from: 0);
        }
      });
    unawaited(_ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setRate(double rate) {
    final t = _ctrl.value;
    setState(() => _rate = rate);
    final realMs = _slice.length < 2
        ? 2000
        : _slice.last.timestamp
            .difference(_slice.first.timestamp)
            .inMilliseconds
            .clamp(800, 45000);
    _ctrl.duration = Duration(milliseconds: (realMs / _rate).round());
    _ctrl.value = t;
    if (_ctrl.isAnimating) {
      unawaited(_ctrl.forward());
    }
  }

  int get _indexInSlice {
    if (_slice.length <= 1) return 0;
    final start = _slice.first.timestamp.millisecondsSinceEpoch;
    final end = _slice.last.timestamp.millisecondsSinceEpoch;
    final span = (end - start).clamp(1, 1 << 30);
    final t = start + (_ctrl.value * span).round();
    // Binary-ish scan for nearest sample.
    var lo = 0;
    var hi = _slice.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_slice[mid].timestamp.millisecondsSinceEpoch < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0) {
      final a = _slice[lo - 1].timestamp.millisecondsSinceEpoch;
      final b = _slice[lo].timestamp.millisecondsSinceEpoch;
      if ((t - a).abs() <= (b - t).abs()) return lo - 1;
    }
    return lo;
  }

  double _relativeLean(TrackPoint p) {
    final raw = p.leanDegrees;
    if (raw == null) return 0;
    return relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: widget.neutralLeanDegrees,
    );
  }

  /// 0–1 braking from local speed drop.
  double _brakeIntensity(int sliceIndex) {
    if (sliceIndex <= 0 || sliceIndex >= _slice.length) return 0;
    final a = _slice[sliceIndex - 1];
    final b = _slice[sliceIndex];
    final v0 = a.speedMps;
    final v1 = b.speedMps;
    if (v0 == null || v1 == null) return 0;
    final dt =
        b.timestamp.difference(a.timestamp).inMilliseconds / 1000.0;
    if (dt <= 0.02) return 0;
    final decel = (v0 - v1) / dt;
    if (decel <= 0.4) return 0;
    return (decel / 7.0).clamp(0.0, 1.0);
  }

  BrakeHardness? _brakeHardness(int globalIndex) {
    for (final e in widget.brakeEvents) {
      if (globalIndex >= e.startIndex && globalIndex <= e.endIndex) {
        return e.hardness;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxLeanL = _slice
        .map(_relativeLean)
        .where((v) => v < 0)
        .fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
    final maxLeanR = _slice
        .map(_relativeLean)
        .where((v) => v > 0)
        .fold<double>(0, (m, v) => v > m ? v : m);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          widget.title ?? l10n.skillReplayTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final si = _indexInSlice;
          final p = _slice[si];
          final global = _lo + si;
          final lean = _relativeLean(p);
          final speed = p.speedKmh ?? 0;
          final brake = _brakeIntensity(si);
          final hardness = _brakeHardness(global);
          final brakeColor = switch (hardness) {
            BrakeHardness.hard => AppTheme.signal,
            BrakeHardness.medium => AppTheme.lineHot,
            BrakeHardness.light => const Color(0xFFFFE082),
            null => AppTheme.lineHot.withValues(alpha: 0.5 + brake * 0.5),
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                l10n.skillReplayHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220,
                  child: PilotLineMap(
                    points: widget.samples,
                    interactive: false,
                    scrubIndex: global,
                    focusStartIndex: _lo,
                    focusEndIndex: _hi,
                    dimOutsideFocus: true,
                    brakeEvents: widget.brakeEvents,
                    layers: const MapLayerOptions(
                      showSpeedColors: true,
                      showBrakes: true,
                      showRoadKindContrast: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MotorcycleLeanGauge(
                leanDegrees: lean,
                maxLeftDegrees: maxLeanL.clamp(10, 70),
                maxRightDegrees: maxLeanR.clamp(10, 70),
                height: 160,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _LiveMetric(
                      label: l10n.speed,
                      value: '${speed.toStringAsFixed(0)} ${l10n.kmh}',
                      accent: RideVizPalette.speedColor(speed),
                      fill: (speed / 180).clamp(0.05, 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LiveMetric(
                      label: l10n.brake,
                      value: brake < 0.05
                          ? '—'
                          : switch (hardness) {
                              BrakeHardness.hard => l10n.brakeHard,
                              BrakeHardness.medium => l10n.brakeMedium,
                              BrakeHardness.light => l10n.brakeLight,
                              null => '${(brake * 100).round()}%',
                            },
                      accent: brakeColor,
                      fill: brake.clamp(0.05, 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDuration(Duration(milliseconds: (p.timestamp.difference(_slice.first.timestamp).inMilliseconds).clamp(0, 1 << 30)))}'
                ' · ${si + 1}/${_slice.length}',
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              _TransportBar(
                playing: _ctrl.isAnimating,
                loop: _loop,
                rate: _rate,
                progress: _ctrl.value,
                onPlayPause: () {
                  if (_ctrl.isAnimating) {
                    _ctrl.stop();
                  } else {
                    if (_ctrl.value >= 0.999) {
                      unawaited(_ctrl.forward(from: 0));
                    } else {
                      unawaited(_ctrl.forward());
                    }
                  }
                  setState(() {});
                },
                onRestart: () {
                  unawaited(_ctrl.forward(from: 0));
                  setState(() {});
                },
                onLoop: () => setState(() => _loop = !_loop),
                onRate: _setRate,
                onSeek: (v) {
                  _ctrl.value = v;
                  setState(() {});
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
    required this.label,
    required this.value,
    required this.accent,
    required this.fill,
  });

  final String label;
  final String value;
  final Color accent;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              letterSpacing: 0.8,
              color: AppTheme.steel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.exo2(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              backgroundColor: AppTheme.asphalt,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportBar extends StatelessWidget {
  const _TransportBar({
    required this.playing,
    required this.loop,
    required this.rate,
    required this.progress,
    required this.onPlayPause,
    required this.onRestart,
    required this.onLoop,
    required this.onRate,
    required this.onSeek,
  });

  final bool playing;
  final bool loop;
  final double rate;
  final double progress;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;
  final VoidCallback onLoop;
  final ValueChanged<double> onRate;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: progress.clamp(0, 1),
              onChanged: onSeek,
              activeColor: AppTheme.line,
              inactiveColor: AppTheme.steel.withValues(alpha: 0.3),
            ),
          ),
          Row(
            children: [
              IconButton(
                tooltip: playing ? l10n.pause : l10n.play,
                onPressed: onPlayPause,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                color: AppTheme.line,
                iconSize: 36,
              ),
              IconButton(
                tooltip: l10n.restart,
                onPressed: onRestart,
                icon: const Icon(Icons.replay),
                color: AppTheme.mist,
              ),
              IconButton(
                tooltip: l10n.loopReplay,
                onPressed: onLoop,
                icon: Icon(
                  Icons.loop,
                  color: loop ? AppTheme.line : AppTheme.steel,
                ),
              ),
              const Spacer(),
              for (final r in const [0.5, 1.0, 2.0])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text('${r}x'),
                    selected: (rate - r).abs() < 0.01,
                    onSelected: (_) => onRate(r),
                    visualDensity: VisualDensity.compact,
                    selectedColor: AppTheme.line.withValues(alpha: 0.25),
                    labelStyle: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
