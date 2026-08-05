import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/curva_analysis.dart';
import '../../core/analytics/lean_neutral.dart';
import '../../core/analytics/track_segment_align.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../compare/compare_widgets.dart';
import 'pilot_line_map.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/motorcycle_lean_gauge.dart';

/// Live replay of a corner: lean, brake, speed + map playhead.
/// Optionally overlays a friend on the **same geographic section**.
class SkillReplayScreen extends ConsumerStatefulWidget {
  const SkillReplayScreen({
    super.key,
    required this.samples,
    required this.analysis,
    required this.neutralLeanDegrees,
    this.brakeEvents = const [],
    this.title,
    this.localRideId,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;
  final double neutralLeanDegrees;
  final List<BrakeEvent> brakeEvents;
  final String? title;
  final String? localRideId;

  @override
  ConsumerState<SkillReplayScreen> createState() => _SkillReplayScreenState();
}

class _SkillReplayScreenState extends ConsumerState<SkillReplayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late List<TrackPoint> _youSlice;
  List<TrackPoint>? _peerSlice;
  CloudRideSummary? _peer;
  bool _loadingPeer = false;
  String? _peerError;
  double _rate = 1;
  bool _loop = true;

  @override
  void initState() {
    super.initState();
    _youSlice = _localCornerSlice();
    final realMs = _durationMsFor(_youSlice);
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

  List<TrackPoint> _localCornerSlice() {
    final n = widget.samples.length;
    final lo = widget.analysis.mapStartIndex.clamp(0, n - 1);
    final hi = widget.analysis.mapEndIndex.clamp(lo, n - 1);
    return widget.samples.sublist(lo, hi + 1);
  }

  int _durationMsFor(List<TrackPoint> slice) {
    if (slice.length < 2) return 2000;
    return slice.last.timestamp
        .difference(slice.first.timestamp)
        .inMilliseconds
        .clamp(800, 45000);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setRate(double rate) {
    final t = _ctrl.value;
    setState(() => _rate = rate);
    _ctrl.duration =
        Duration(milliseconds: (_durationMsFor(_youSlice) / _rate).round());
    _ctrl.value = t;
    if (_ctrl.isAnimating) {
      unawaited(_ctrl.forward());
    }
  }

  Future<void> _selectPeer(CloudRideSummary? peer) async {
    if (peer == null) {
      setState(() {
        _peer = null;
        _peerSlice = null;
        _peerError = null;
        _youSlice = _localCornerSlice();
        _loadingPeer = false;
      });
      _resyncDuration();
      return;
    }
    setState(() {
      _peer = peer;
      _peerSlice = null;
      _peerError = null;
      _loadingPeer = true;
    });
    try {
      final cloud =
          await ref.read(socialRepositoryProvider).trackPoints(peer.id);
      if (!mounted) return;
      final peerPts = trackPointsFromCloud(cloud, rideId: peer.id);
      final aligned = alignCornerToPeer(
        localSamples: widget.samples,
        mapStartIndex: widget.analysis.mapStartIndex,
        mapEndIndex: widget.analysis.mapEndIndex,
        peerSamples: peerPts,
      );
      if (!mounted) return;
      if (aligned == null || !aligned.isUsable) {
        setState(() {
          _loadingPeer = false;
          _peerSlice = null;
          _youSlice = _localCornerSlice();
          _peerError = context.l10n.skillReplayNoPeerMatch;
        });
        return;
      }
      setState(() {
        _loadingPeer = false;
        _youSlice = aligned.left;
        _peerSlice = aligned.right;
        _peerError = null;
      });
      _resyncDuration();
      unawaited(_ctrl.forward(from: 0));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPeer = false;
        _peerError = context.l10n.compareTrackUnavailable;
      });
    }
  }

  void _resyncDuration() {
    final t = _ctrl.value;
    _ctrl.duration =
        Duration(milliseconds: (_durationMsFor(_youSlice) / _rate).round());
    _ctrl.value = t;
  }

  double _relativeLean(TrackPoint p) {
    final raw = p.leanDegrees;
    if (raw == null) return 0;
    return relativeLeanDegrees(
      rawLeanDegrees: raw,
      neutralDegrees: widget.neutralLeanDegrees,
    );
  }

  double _brakeIntensity(List<TrackPoint> slice, int sliceIndex) {
    if (sliceIndex <= 0 || sliceIndex >= slice.length) return 0;
    final a = slice[sliceIndex - 1];
    final b = slice[sliceIndex];
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final peersAsync = widget.localRideId == null
        ? null
        : ref.watch(overlappingPeersProvider(widget.localRideId!));
    final comparing = _peerSlice != null && _peerSlice!.length >= 2;

    final maxLeanL = [
      ..._youSlice.map(_relativeLean),
      if (comparing) ..._peerSlice!.map(_relativeLean),
    ].where((v) => v < 0).fold<double>(0, (m, v) => v.abs() > m ? v.abs() : m);
    final maxLeanR = [
      ..._youSlice.map(_relativeLean),
      if (comparing) ..._peerSlice!.map(_relativeLean),
    ].where((v) => v > 0).fold<double>(0, (m, v) => v > m ? v : m);

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
          final yi = indexAtPathFraction(_youSlice, _ctrl.value);
          final pi = comparing
              ? indexAtPathFraction(_peerSlice!, _ctrl.value)
              : 0;
          final yp = _youSlice[yi];
          final pp = comparing ? _peerSlice![pi] : null;
          final leanYou = _relativeLean(yp);
          final leanPeer = pp == null ? null : _relativeLean(pp);
          final speedYou = yp.speedKmh ?? 0;
          final speedPeer = pp?.speedKmh;
          final brakeYou = _brakeIntensity(_youSlice, yi);
          final brakePeer =
              pp == null ? null : _brakeIntensity(_peerSlice!, pi);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                comparing
                    ? l10n.skillReplayCompareHelp
                    : l10n.skillReplayHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (peersAsync != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.skillReplayCompareWith,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                peersAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, _) => Text(
                    l10n.cloudUnavailable,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                  ),
                  data: (peers) {
                    if (peers.isEmpty) {
                      return Text(
                        l10n.compareEmpty,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 12,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.compareYou),
                          selected: _peer == null,
                          onSelected: (_) => _selectPeer(null),
                          selectedColor:
                              RideVizPalette.leanLeft.withValues(alpha: 0.25),
                        ),
                        for (final p in peers.take(8))
                          ChoiceChip(
                            label: Text(p.riderLabel),
                            selected: _peer?.id == p.id,
                            onSelected: (_) => _selectPeer(p),
                            selectedColor: RideVizPalette.leanRight
                                .withValues(alpha: 0.25),
                          ),
                      ],
                    );
                  },
                ),
                if (_loadingPeer) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_peerError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _peerError!,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.lineHot,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              if (comparing)
                DualPolylineMap(
                  left: [
                    for (final p in _youSlice)
                      LatLng(p.latitude, p.longitude),
                  ],
                  right: [
                    for (final p in _peerSlice!)
                      LatLng(p.latitude, p.longitude),
                  ],
                  leftLabel: l10n.compareYou,
                  rightLabel: _peer?.riderLabel ?? l10n.compareChallenger,
                  caption: l10n.skillReplayAlignedSection,
                  leftPlayhead: LatLng(yp.latitude, yp.longitude),
                  rightPlayhead: LatLng(pp!.latitude, pp.longitude),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 260,
                    child: PilotLineMap(
                      points: widget.samples,
                      interactive: false,
                      allowZoom: true,
                      scrubIndex: widget.analysis.mapStartIndex +
                          yi.clamp(0, _youSlice.length - 1),
                      focusStartIndex: widget.analysis.mapStartIndex,
                      focusEndIndex: widget.analysis.mapEndIndex,
                      dimOutsideFocus: true,
                      brakeEvents: widget.brakeEvents,
                      layers: const MapLayerOptions(
                        showSpeedColors: true,
                        showBrakes: true,
                        showRoadKindContrast: false,
                        showLegend: false,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (comparing)
                Row(
                  children: [
                    Expanded(
                      child: MotorcycleLeanGauge(
                        leanDegrees: leanYou,
                        maxLeftDegrees: maxLeanL.clamp(10, 70),
                        maxRightDegrees: maxLeanR.clamp(10, 70),
                        height: 140,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MotorcycleLeanGauge(
                        leanDegrees: leanPeer ?? 0,
                        maxLeftDegrees: maxLeanL.clamp(10, 70),
                        maxRightDegrees: maxLeanR.clamp(10, 70),
                        height: 140,
                      ),
                    ),
                  ],
                )
              else
                MotorcycleLeanGauge(
                  leanDegrees: leanYou,
                  maxLeftDegrees: maxLeanL.clamp(10, 70),
                  maxRightDegrees: maxLeanR.clamp(10, 70),
                  height: 160,
                ),
              if (comparing) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.compareYou,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          color: RideVizPalette.leanLeft,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _peer?.riderLabel ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          color: RideVizPalette.leanRight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (comparing)
                Row(
                  children: [
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.speed,
                        value: '${speedYou.toStringAsFixed(0)} ${l10n.kmh}',
                        accent: RideVizPalette.leanLeft,
                        fill: (speedYou / 180).clamp(0.05, 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.speed,
                        value:
                            '${(speedPeer ?? 0).toStringAsFixed(0)} ${l10n.kmh}',
                        accent: RideVizPalette.leanRight,
                        fill: ((speedPeer ?? 0) / 180).clamp(0.05, 1),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.speed,
                        value: '${speedYou.toStringAsFixed(0)} ${l10n.kmh}',
                        accent: RideVizPalette.speedColor(speedYou),
                        fill: (speedYou / 180).clamp(0.05, 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.brake,
                        value: brakeYou < 0.05
                            ? '—'
                            : '${(brakeYou * 100).round()}%',
                        accent: AppTheme.lineHot
                            .withValues(alpha: 0.5 + brakeYou * 0.5),
                        fill: brakeYou.clamp(0.05, 1),
                      ),
                    ),
                  ],
                ),
              if (comparing) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.brake,
                        value: brakeYou < 0.05
                            ? '—'
                            : '${(brakeYou * 100).round()}%',
                        accent: RideVizPalette.leanLeft,
                        fill: brakeYou.clamp(0.05, 1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _LiveMetric(
                        label: l10n.brake,
                        value: (brakePeer ?? 0) < 0.05
                            ? '—'
                            : '${((brakePeer ?? 0) * 100).round()}%',
                        accent: RideVizPalette.leanRight,
                        fill: (brakePeer ?? 0).clamp(0.05, 1),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                comparing
                    ? '${(_ctrl.value * 100).round()}% · '
                        '${l10n.skillReplaySameSection}'
                    : '${formatDuration(Duration(milliseconds: (yp.timestamp.difference(_youSlice.first.timestamp).inMilliseconds).clamp(0, 1 << 30)))}'
                        ' · ${yi + 1}/${_youSlice.length}',
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
