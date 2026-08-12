import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/lean_neutral.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/lean_lab/grade_profile.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/lean_lab/max_lean_locator.dart';
import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../ride_detail/pilot_line_map.dart';
import '../ride_detail/widgets/map_layer_toggles.dart';
import '../ride_detail/widgets/motorcycle_lean_gauge.dart';

/// Label top corners after a Lean Lab lap — max lean + animated replay.
class LeanLabReviewScreen extends ConsumerStatefulWidget {
  const LeanLabReviewScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<LeanLabReviewScreen> createState() =>
      _LeanLabReviewScreenState();
}

class _LeanLabReviewScreenState extends ConsumerState<LeanLabReviewScreen>
    with SingleTickerProviderStateMixin {
  LeanLabSession? _session;
  RideAnalytics? _analytics;
  GradeProfile? _grade;
  final Map<int, LeanBiasLabel> _biasByPeak = {};
  bool _saving = false;
  int _cornerIndex = 0;
  double _rate = 1;
  bool _loop = true;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _loop && mounted) {
          unawaited(_ctrl.forward(from: 0));
        }
      });
    unawaited(_load());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Ensure track (+ lean) is local before detecting corners.
    try {
      await ref.read(rideSyncServiceProvider).pullMyCloudRides();
    } catch (_) {}
    final session = await LeanLabService.instance.getSession(widget.rideId);
    var ride = await ref.read(rideProvider(widget.rideId).future);
    var points = await ref.read(ridePointsProvider(widget.rideId).future);
    // If this phone wiped its track earlier, push/pull once more after keep-local fix.
    if (points.length < 4) {
      try {
        await ref.read(rideSyncServiceProvider).syncRide(widget.rideId);
        await ref.read(rideSyncServiceProvider).pullMyCloudRides();
        ref.invalidate(rideProvider(widget.rideId));
        ref.invalidate(ridePointsProvider(widget.rideId));
        ride = await ref.read(rideProvider(widget.rideId).future);
        points = await ref.read(ridePointsProvider(widget.rideId).future);
      } catch (_) {}
    }
    if (!mounted || ride == null) return;
    final analytics = RideAnalytics(
      ride: ride,
      points: points,
      neutralLeanOverride: session?.frozenNeutralDeg,
    );
    final grade = buildGradeProfile(analytics.samples);
    setState(() {
      _session = session;
      _analytics = analytics;
      _grade = grade;
      for (final c in session?.corners ?? const <LeanLabCornerLabel>[]) {
        final key = c.maxLeanIndex ?? c.apexIndex;
        _biasByPeak[key] = c.bias;
      }
    });
    _resyncAnimForCorner(0);
  }

  double get _neutral =>
      _session?.frozenNeutralDeg ?? _analytics?.neutralLeanDegrees ?? 0;

  List<_CornerCandidate> get _candidates {
    final a = _analytics;
    if (a == null) return const [];
    final built = <_CornerCandidate>[];
    final usedPeaks = <int>{};

    void addCandidate({
      required String label,
      required int start,
      required int end,
      required int apex,
      required MaxLeanHit hit,
    }) {
      if (usedPeaks.any((p) => (p - hit.peakIndex).abs() < 6)) return;
      usedPeaks.add(hit.peakIndex);
      built.add(
        _CornerCandidate(
          label: label,
          analysisStart: start,
          analysisEnd: end,
          apexIndex: apex,
          maxLean: hit,
        ),
      );
    }

    // 1) Primary: road-stretch skill corners.
    for (final c in a.skillSummary.corners) {
      final hit = findMaxLeanInWindow(
        samples: a.samples,
        lo: c.analysis.mapStartIndex,
        hi: c.analysis.mapEndIndex,
        neutralLeanDegrees: _neutral,
      );
      if (hit == null) continue;
      addCandidate(
        label: c.label,
        start: c.analysis.mapStartIndex,
        end: c.analysis.mapEndIndex,
        apex: c.analysis.apexIndex,
        hit: hit,
      );
    }

    // 2) Curve engine events (heading + lean), if skill missed them.
    if (built.length < 5) {
      for (final e in a.curveEvents) {
        final hit = findMaxLeanInWindow(
          samples: a.samples,
          lo: e.startIndex,
          hi: e.endIndex,
          neutralLeanDegrees: _neutral,
        );
        if (hit == null || hit.absLeanDeg < 10) continue;
        final side = hit.side == 'left' ? 'Curva izquierda' : 'Curva derecha';
        addCandidate(
          label: side,
          start: e.startIndex,
          end: e.endIndex,
          apex: e.apexIndex ?? ((e.startIndex + e.endIndex) ~/ 2),
          hit: hit,
        );
        if (built.length >= 5) break;
      }
    }

    // 3) Raw lean peaks — recovers Bugambilias rides when stretch gating is strict.
    if (built.length < 3) {
      final peaks = findTopLeanPeaks(
        samples: a.samples,
        neutralLeanDegrees: _neutral,
        maxPeaks: 5,
      );
      for (final hit in peaks) {
        final lo = (hit.peakIndex - 8).clamp(0, a.samples.length - 1);
        final hi = (hit.peakIndex + 8).clamp(lo, a.samples.length - 1);
        final side = hit.side == 'left' ? 'Curva izquierda' : 'Curva derecha';
        addCandidate(
          label: side,
          start: lo,
          end: hi,
          apex: hit.peakIndex,
          hit: hit,
        );
        if (built.length >= 5) break;
      }
    }

    // 4) Already-saved labels (relabel / restored cloud session).
    if (built.isEmpty && a.samples.isNotEmpty) {
      final last = a.samples.length - 1;
      for (final c in _session?.corners ?? const <LeanLabCornerLabel>[]) {
        final peak = (c.maxLeanIndex ?? c.apexIndex).clamp(0, last);
        final lo = c.mapStartIndex.clamp(0, last);
        final hi = c.mapEndIndex.clamp(lo, last);
        var hit = findMaxLeanInWindow(
          samples: a.samples,
          lo: lo,
          hi: hi,
          neutralLeanDegrees: _neutral,
        );
        if (hit == null) {
          final from = (c.maxLeanFromIndex ?? lo).clamp(0, last);
          final to = (c.maxLeanToIndex ?? hi).clamp(from, last);
          hit = MaxLeanHit(
            peakIndex: peak,
            signedLeanDeg: c.appLeanDeg,
            fromIndex: from,
            toIndex: to,
            fromPoint: a.samples[from],
            toPoint: a.samples[to],
          );
        }
        final side = hit.side == 'left' ? 'Curva izquierda' : 'Curva derecha';
        addCandidate(
          label: side,
          start: lo,
          end: hi,
          apex: c.apexIndex.clamp(0, last),
          hit: hit,
        );
      }
    }

    built.sort(
      (x, y) => y.maxLean.absLeanDeg.compareTo(x.maxLean.absLeanDeg),
    );
    return built.take(5).toList();
  }

  String _emptyReason(AppLocalizations l10n) {
    final a = _analytics;
    if (a == null) return l10n.leanLabNoCorners;
    if (a.samples.length < 4) return l10n.leanLabNoTrackPoints;
    final leanN = a.samples.where((p) => p.leanDegrees != null).length;
    if (leanN < 8) return l10n.leanLabNoLeanData;
    return l10n.leanLabNoCorners;
  }

  List<TrackPoint> _sliceFor(_CornerCandidate c) {
    final samples = _analytics?.samples ?? const <TrackPoint>[];
    if (samples.isEmpty) return const [];
    final lo = c.analysisStart.clamp(0, samples.length - 1);
    final hi = c.analysisEnd.clamp(lo, samples.length - 1);
    return samples.sublist(lo, hi + 1);
  }

  int _durationMs(List<TrackPoint> slice) {
    if (slice.length < 2) return 2500;
    return slice.last.timestamp
        .difference(slice.first.timestamp)
        .inMilliseconds
        .clamp(800, 45000);
  }

  void _resyncAnimForCorner(int index) {
    final cands = _candidates;
    if (cands.isEmpty) return;
    final c = cands[index.clamp(0, cands.length - 1)];
    final slice = _sliceFor(c);
    _ctrl.duration =
        Duration(milliseconds: (_durationMs(slice) / _rate).round());
    unawaited(_ctrl.forward(from: 0));
  }

  void _goCorner(int index) {
    setState(() => _cornerIndex = index);
    _resyncAnimForCorner(index);
  }

  void _setRate(double rate) {
    final t = _ctrl.value;
    setState(() => _rate = rate);
    final cands = _candidates;
    if (cands.isEmpty) return;
    final c = cands[_cornerIndex.clamp(0, cands.length - 1)];
    _ctrl.duration =
        Duration(milliseconds: (_durationMs(_sliceFor(c)) / _rate).round());
    _ctrl.value = t;
    if (_ctrl.isAnimating) unawaited(_ctrl.forward());
  }

  /// Playhead index into full ride samples for current animation value.
  int _playheadGlobal(_CornerCandidate c) {
    final slice = _sliceFor(c);
    if (slice.isEmpty) return c.analysisStart;
    if (slice.length == 1) return c.analysisStart;
    final start = slice.first.timestamp.millisecondsSinceEpoch;
    final end = slice.last.timestamp.millisecondsSinceEpoch;
    final span = (end - start).clamp(1, 1 << 30);
    final t = start + (_ctrl.value * span).round();
    var lo = 0;
    var hi = slice.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (slice[mid].timestamp.millisecondsSinceEpoch < t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo > 0) {
      final a = slice[lo - 1].timestamp.millisecondsSinceEpoch;
      final b = slice[lo].timestamp.millisecondsSinceEpoch;
      if ((t - a).abs() <= (b - t).abs()) lo = lo - 1;
    }
    return c.analysisStart + lo;
  }

  Future<void> _save() async {
    final session = _session;
    final analytics = _analytics;
    final grade = _grade;
    if (session == null || analytics == null || grade == null) return;
    setState(() => _saving = true);
    final labels = <LeanLabCornerLabel>[];
    for (final c in _candidates) {
      final hit = c.maxLean;
      final bias = _biasByPeak[hit.peakIndex] ?? LeanBiasLabel.unsure;
      labels.add(
        LeanLabCornerLabel(
          mapStartIndex: c.analysisStart,
          mapEndIndex: c.analysisEnd,
          apexIndex: c.apexIndex,
          side: hit.side,
          appLeanDeg: hit.signedLeanDeg,
          bias: bias,
          avgGradePct: grade.averageGradePct(c.analysisStart, c.analysisEnd),
          deltaAltM: grade.altitudeDelta(c.analysisStart, c.analysisEnd),
          vertTrend: grade.dominantTrend(c.analysisStart, c.analysisEnd),
          confidence: bias == LeanBiasLabel.unsure ? 2 : 4,
          maxLeanIndex: hit.peakIndex,
          maxLeanFromIndex: hit.fromIndex,
          maxLeanToIndex: hit.toIndex,
          maxLeanFromLat: hit.fromPoint.latitude,
          maxLeanFromLng: hit.fromPoint.longitude,
          maxLeanToLat: hit.toPoint.latitude,
          maxLeanToLng: hit.toPoint.longitude,
        ),
      );
    }
    await LeanLabService.instance.saveCornerLabels(
      rideId: widget.rideId,
      corners: labels,
      analytics: analytics,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final analytics = _analytics;
    final candidates = _candidates;
    final session = _session;

    if (analytics == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.leanLabReviewTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _emptyReason(l10n),
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final i = _cornerIndex.clamp(0, candidates.length - 1);
    final c = candidates[i];
    final hit = c.maxLean;
    final grade = _grade;
    final avgGrade =
        grade?.averageGradePct(c.analysisStart, c.analysisEnd) ?? 0;
    final trend =
        grade?.dominantTrend(c.analysisStart, c.analysisEnd) ?? VertTrend.unknown;
    final bias = _biasByPeak[hit.peakIndex] ?? LeanBiasLabel.unsure;
    final sideLabel =
        hit.side == 'left' ? l10n.leanLabSideLeft : l10n.leanLabSideRight;
    final gaugeMax = (hit.absLeanDeg + 8).clamp(25.0, 70.0);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanLabReviewTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final playGlobal = _playheadGlobal(c);
          final playPt = analytics.samples[
              playGlobal.clamp(0, analytics.samples.length - 1)];
          final liveLean = relativeLeanDegrees(
            rawLeanDegrees: playPt.leanDegrees ?? 0,
            neutralDegrees: _neutral,
          );
          final atMax = (playGlobal - hit.peakIndex).abs() <= 1;
          final liveSpeed = playPt.speedKmh ?? 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                l10n.leanLabReviewHelpMax,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (session != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${session.direction.id} · ${session.phoneMount} · '
                  '${l10n.leanLabElevationSummary(session.totalClimbM.toStringAsFixed(0), session.totalDescentM.toStringAsFixed(0))}',
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.mist,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: i > 0 ? () => _goCorner(i - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '${i + 1}/${candidates.length} · ${c.label}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: i < candidates.length - 1
                        ? () => _goCorner(i + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              // Fixed max for this curve (score this).
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.asphaltElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: RideVizPalette.leanColor(hit.signedLeanDeg)
                        .withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.leanLabMaxLean.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        letterSpacing: 1.2,
                        color: AppTheme.steel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${hit.absLeanDeg.toStringAsFixed(0)}°',
                      style: GoogleFonts.exo2(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: RideVizPalette.leanColor(hit.signedLeanDeg),
                        height: 1.05,
                      ),
                    ),
                    Text(
                      sideLabel,
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.mist,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () {
                        final slice = _sliceFor(c);
                        if (slice.isEmpty) return;
                        final peakInSlice =
                            (hit.peakIndex - c.analysisStart)
                                .clamp(0, slice.length - 1);
                        final t = slice.length <= 1
                            ? 0.0
                            : peakInSlice / (slice.length - 1);
                        _ctrl.value = t;
                        setState(() {});
                      },
                      icon: const Icon(Icons.flag, size: 18),
                      label: Text(l10n.leanLabJumpToMax),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 220,
                  child: Builder(
                    builder: (context) {
                      // Always keep GPS line on both sides of max lean.
                      final mapFocus = padTrackAroundIndex(
                        samples: analytics.samples,
                        centerIndex: hit.peakIndex,
                        seedLo: c.analysisStart,
                        seedHi: c.analysisEnd,
                      );
                      return PilotLineMap(
                        points: analytics.samples,
                        interactive: false,
                        allowZoom: true,
                        scrubIndex: playGlobal,
                        focusStartIndex: mapFocus.lo,
                        focusEndIndex: mapFocus.hi,
                        accentIndex: hit.peakIndex,
                        dimOutsideFocus: true,
                        layers: const MapLayerOptions(
                          showSpeedColors: true,
                          showBrakes: false,
                          showRoadKindContrast: false,
                          showLegend: false,
                          showStartEnd: false,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.leanLabMaxLeanGps,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.leanLabMaxLeanGpsA(
                  hit.fromPoint.latitude.toStringAsFixed(6),
                  hit.fromPoint.longitude.toStringAsFixed(6),
                ),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              Text(
                l10n.leanLabMaxLeanGpsB(
                  hit.toPoint.latitude.toStringAsFixed(6),
                  hit.toPoint.longitude.toStringAsFixed(6),
                ),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              MotorcycleLeanGauge(
                leanDegrees: liveLean,
                maxLeftDegrees: gaugeMax,
                maxRightDegrees: gaugeMax,
                height: 140,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.leanLabLiveLean}: ${liveLean.abs().toStringAsFixed(0)}°'
                      '${atMax ? ' · ${l10n.leanLabAtPeak}' : ''}',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        color: atMax
                            ? RideVizPalette.leanColor(hit.signedLeanDeg)
                            : AppTheme.mist,
                      ),
                    ),
                  ),
                  Text(
                    '${liveSpeed.toStringAsFixed(0)} ${l10n.kmh}',
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.leanLabGrade}: ${avgGrade.toStringAsFixed(1)}%'
                ' · ${_trendLabel(l10n, trend)}',
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              _TransportBar(
                playing: _ctrl.isAnimating,
                loop: _loop,
                rate: _rate,
                progress: _ctrl.value,
                onPlayPause: () {
                  if (_ctrl.isAnimating) {
                    _ctrl.stop();
                  } else if (_ctrl.value >= 0.999) {
                    unawaited(_ctrl.forward(from: 0));
                  } else {
                    unawaited(_ctrl.forward());
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
              const SizedBox(height: 14),
              Text(
                l10n.leanLabBiasQ,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in LeanBiasLabel.values)
                    ChoiceChip(
                      label: Text(_biasLabel(l10n, b)),
                      selected: bias == b,
                      selectedColor:
                          RideVizPalette.leanLeft.withValues(alpha: 0.25),
                      onSelected: (_) =>
                          setState(() => _biasByPeak[hit.peakIndex] = b),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(l10n.leanLabSaveLabels),
              ),
            ],
          );
        },
      ),
    );
  }

  String _biasLabel(AppLocalizations l10n, LeanBiasLabel b) => switch (b) {
        LeanBiasLabel.appHigh => l10n.leanLabBiasAppHigh,
        LeanBiasLabel.ok => l10n.leanLabBiasOk,
        LeanBiasLabel.appLow => l10n.leanLabBiasAppLow,
        LeanBiasLabel.unsure => l10n.leanLabBiasUnsure,
      };

  String _trendLabel(AppLocalizations l10n, VertTrend t) => switch (t) {
        VertTrend.climbing => l10n.leanLabTrendClimbing,
        VertTrend.descending => l10n.leanLabTrendDescending,
        VertTrend.flat => l10n.leanLabTrendFlat,
        VertTrend.unknown => '—',
      };
}

class _CornerCandidate {
  const _CornerCandidate({
    required this.label,
    required this.analysisStart,
    required this.analysisEnd,
    required this.apexIndex,
    required this.maxLean,
  });

  final String label;
  final int analysisStart;
  final int analysisEnd;
  final int apexIndex;
  final MaxLeanHit maxLean;
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
