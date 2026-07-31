import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/curva_analysis.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/pro_entitlement_provider.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import '../../theme/ride_viz_palette.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/pro_upsell.dart';
import '../../widgets/rider_alias_chip.dart';
import '../compare/ride_compare_screen.dart';
import '../compare/route_compare_screen.dart';
import '../pro/pro_upsell.dart';
import 'curva_detail_screen.dart';
import 'fullscreen_map_screen.dart';
import 'pilot_line_map.dart';
import 'widgets/brake_events_panel.dart';
import 'widgets/lab_section.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/motorcycle_lean_gauge.dart';
import 'widgets/ride_profile_chart.dart';
import 'widgets/ride_share_panel.dart';
import 'widgets/road_stretches_panel.dart';
import 'widgets/segment_range_panel.dart';

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(rideProvider(rideId));
    final pointsAsync = ref.watch(ridePointsProvider(rideId));
    final l10n = context.l10n;

    return Scaffold(
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ride) {
          if (ride == null) {
            return Center(child: Text(l10n.rideNotFound));
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

class _RideDashboard extends ConsumerStatefulWidget {
  const _RideDashboard({
    required this.rideId,
    required this.analytics,
  });

  final String rideId;
  final RideAnalytics analytics;

  @override
  ConsumerState<_RideDashboard> createState() => _RideDashboardState();
}

class _RideDashboardState extends ConsumerState<_RideDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late int _scrubIndex;
  late int _segStart;
  late int _segEnd;
  bool _zoomed = false;
  MapLayerOptions _mapLayers = const MapLayerOptions();

  final Set<String> _expanded = {
    'overview',
    'map',
  };

  RideAnalytics get _full => widget.analytics;

  bool _isOpen(String id) => _expanded.contains(id);

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    final samples = _full.samples;
    _scrubIndex = samples.isEmpty ? 0 : samples.length ~/ 2;
    if (samples.length < 2) {
      _segStart = 0;
      _segEnd = 0;
    } else {
      _segStart = (samples.length * 0.2).floor().clamp(0, samples.length - 2);
      _segEnd = (samples.length * 0.8).ceil().clamp(_segStart + 1, samples.length - 1);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  RideAnalytics get _view {
    if (!_zoomed || _full.samples.length < 2) return _full;
    return _full.segment(_segStart, _segEnd);
  }

  void _setScrubIndex(int index) {
    final view = _view;
    final max = view.samples.length - 1;
    if (max < 0) return;
    setState(() => _scrubIndex = index.clamp(0, max));
  }

  void _setScrubSeconds(double seconds) {
    _setScrubIndex(_view.indexForSeconds(seconds));
  }

  /// Zoom map + metrics window onto a brake pulse (indices are view-local).
  void _zoomToBrake(BrakeEvent event) {
    if (!ref.read(isProProvider)) {
      showProUpsellSheet(context, ref);
      return;
    }
    final full = _full;
    if (full.samples.length < 2) return;
    final view = _view;
    final absStart = view.mapIndexOffset + event.startIndex;
    final absEnd = view.mapIndexOffset + event.endIndex;
    const pad = 6;
    final lo = (absStart - pad).clamp(0, full.samples.length - 2);
    final hi = (absEnd + pad).clamp(lo + 1, full.samples.length - 1);
    setState(() {
      _segStart = lo;
      _segEnd = hi;
      _zoomed = true;
      final len = hi - lo + 1;
      final localMid = ((absStart + absEnd) ~/ 2) - lo;
      _scrubIndex = localMid.clamp(0, len - 1);
      _expanded.addAll({'map', 'brakes', 'segment', 'overview'});
    });
  }

  void _setSegmentRange(int start, int end) {
    final max = _full.samples.length - 1;
    if (max < 1) return;
    final lo = start.clamp(0, max - 1);
    final hi = end.clamp(lo + 1, max);
    setState(() {
      _segStart = lo;
      _segEnd = hi;
      if (_zoomed) {
        final view = _full.segment(lo, hi);
        _scrubIndex = (_scrubIndex).clamp(0, view.samples.length - 1);
      }
    });
  }

  void _zoomToSegment() {
    if (!ref.read(isProProvider)) {
      showProUpsellSheet(context, ref);
      return;
    }
    if (_segEnd <= _segStart) return;
    setState(() {
      _zoomed = true;
      final len = _segEnd - _segStart + 1;
      _scrubIndex = (len ~/ 2).clamp(0, len - 1);
    });
  }

  void _clearSegmentZoom() {
    setState(() {
      _zoomed = false;
      _scrubIndex =
          ((_segStart + _segEnd) ~/ 2).clamp(0, _full.samples.length - 1);
    });
  }

  Future<void> _openFullscreenMap() async {
    final full = _full;
    if (full.samples.length < 2) return;
    final absoluteScrub = _zoomed
        ? (_segStart + _scrubIndex).clamp(0, full.samples.length - 1)
        : _scrubIndex.clamp(0, full.samples.length - 1);

    final result = await Navigator.of(context).push<FullscreenMapSelection>(
      MaterialPageRoute(
        builder: (_) => FullscreenMapScreen(
          points: full.samples,
          scrubIndex: absoluteScrub,
          brakeEvents: full.brakeEvents,
          roadStretches: full.roadStretches,
          initialLayers: _mapLayers,
          initialFocusStart: _zoomed ? _segStart : null,
          initialFocusEnd: _zoomed ? _segEnd : null,
        ),
      ),
    );
    if (!mounted) return;
    // Keep toggles in sync if fullscreen mutated them via shared pattern —
    // fullscreen owns a copy; parent keeps its own until we return.
    if (result == null) return;
    if (!ref.read(isProProvider)) {
      showProUpsellSheet(context, ref);
      return;
    }
    setState(() {
      _segStart = result.startIndex;
      _segEnd = result.endIndex;
      _zoomed = true;
      final len = _segEnd - _segStart + 1;
      _scrubIndex = (len ~/ 2).clamp(0, len - 1);
      _expanded.addAll({'overview', 'map', 'segment'});
    });
  }

  Future<void> _openRoadStretch(int stretchIndex) async {
    final a = _view;
    if (stretchIndex < 0 || stretchIndex >= a.roadStretches.length) return;
    final stretch = a.roadStretches[stretchIndex];

    if (stretch.kind == RoadKind.recta) {
      // Focus Ride Lab on this straight (Pro).
      if (!ref.read(isProProvider)) {
        showProUpsellSheet(context, ref);
        return;
      }
      setState(() {
        _segStart = stretch.startIndex;
        _segEnd = stretch.endIndex;
        _zoomed = stretch.endIndex > stretch.startIndex;
        final len = _segEnd - _segStart + 1;
        _scrubIndex = 0;
        if (_zoomed) {
          _scrubIndex = (len ~/ 2).clamp(0, len - 1);
          _expanded.addAll({'overview', 'map', 'segment'});
        }
      });
      return;
    }

    final analyses = <CurvaAnalysis>[];
    var initial = 0;
    for (var i = 0; i < a.roadStretches.length; i++) {
      final s = a.roadStretches[i];
      if (s.kind != RoadKind.curva) continue;
      final analysis = CurvaAnalysis.fromRide(
        samples: a.samples,
        stretch: s,
        neutralLeanDegrees: a.neutralLeanDegrees,
      );
      if (analysis == null) continue;
      if (i == stretchIndex) initial = analyses.length;
      analyses.add(analysis);
    }

    if (analyses.isEmpty) {
      _setScrubIndex(stretch.startIndex);
      return;
    }

    final result = await Navigator.of(context).push<FullscreenMapSelection>(
      MaterialPageRoute(
        builder: (_) => CurvaDetailScreen(
          samples: a.samples,
          analyses: analyses,
          initialIndex: initial,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (!ref.read(isProProvider)) {
      showProUpsellSheet(context, ref);
      return;
    }
    setState(() {
      _segStart = result.startIndex;
      _segEnd = result.endIndex;
      _zoomed = true;
      final len = _segEnd - _segStart + 1;
      _scrubIndex = (len ~/ 2).clamp(0, len - 1);
      _expanded.addAll({'overview', 'map', 'segment'});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPro = ref.watch(isProProvider);
    ref.listen<bool>(isProProvider, (prev, next) {
      if (!next && _zoomed) {
        _clearSegmentZoom();
      }
    });
    final full = _full;
    final a = _view;
    final ride = full.ride;
    final hasSamples = a.samples.isNotEmpty;
    final scrubSeconds = hasSamples ? a.secondsForIndex(_scrubIndex) : 0.0;
    final scrubPoint = hasSamples ? a.samples[_scrubIndex] : null;
    final scrubLean = hasSamples ? a.relativeLeanAt(_scrubIndex) : 0.0;
    final mapScrub = hasSamples ? a.mapIndexOffset + _scrubIndex : null;

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
                  _zoomed ? l10n.rideLabSegment : l10n.rideLab,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
                actions: const [
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(child: RiderAliasChip(compact: true)),
                  ),
                ],
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
                        const RiderLabMark(size: BrandMarkSize.eyebrow),
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
                          _zoomed ? l10n.segmentZoomHint : l10n.collapseHint,
                          style: GoogleFonts.outfit(
                            color: AppTheme.steel,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            CompareLocalRouteEntry(ride: ride),
                            ComparePeersEntry(localRideId: ride.id),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RideSharePanel(ride: ride),
                        const SizedBox(height: 16),
                        if (full.samples.length >= 2)
                          LabSection(
                            title: l10n.sectionSegment,
                            subtitle: l10n.sectionSegmentSub,
                            expanded: _isOpen('segment'),
                            onToggle: () => _toggle('segment'),
                            child: SegmentRangePanel(
                              totalPoints: full.samples.length,
                              startIndex: _segStart,
                              endIndex: _segEnd,
                              startSeconds: full.secondsForIndex(_segStart),
                              endSeconds: full.secondsForIndex(_segEnd),
                              zoomed: _zoomed,
                              isPro: isPro,
                              onRangeChanged: _setSegmentRange,
                              onZoom: _zoomToSegment,
                              onClear: _clearSegmentZoom,
                              onUpgrade: () => showProUpsellSheet(context, ref),
                            ),
                          ),
                        LabSection(
                          title: l10n.sectionOverview,
                          subtitle: _zoomed
                              ? l10n.sectionOverviewSubZoom
                              : l10n.sectionOverviewSub,
                          badge: '${a.lineScore}',
                          expanded: _isOpen('overview'),
                          onToggle: () => _toggle('overview'),
                          child: Column(
                            children: [
                              _ScoreHero(
                                score: a.lineScore,
                                label: _zoomed
                                    ? '${a.lineScoreLabel} · segment'
                                    : a.lineScoreLabel,
                                animation: _intro,
                              ),
                              const SizedBox(height: 16),
                              _MetricGrid(analytics: a),
                            ],
                          ),
                        ),
                        if (a.leanSides.sampleCount > 0)
                          LabSection(
                            title: l10n.sectionLean,
                            subtitle: l10n.sectionLeanSub,
                            expanded: _isOpen('lean'),
                            onToggle: () => _toggle('lean'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MotorcycleLeanGauge(
                                  leanDegrees: scrubLean,
                                  maxLeftDegrees: a.maxLeanLeft,
                                  maxRightDegrees: a.maxLeanRight,
                                  neutralLabel:
                                      'At playhead · neutral offset ${a.neutralLeanDegrees.toStringAsFixed(0)}°',
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.leanHelp,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.steel,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.leanPhoneDisclaimer,
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.mist.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        LabSection(
                          title: l10n.sectionMap,
                          subtitle: l10n.sectionMapSub,
                          expanded: _isOpen('map'),
                          onToggle: () => _toggle('map'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _zoomed
                                          ? l10n.mapHintZoom
                                          : l10n.mapHint,
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.steel,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: full.samples.length >= 2
                                        ? _openFullscreenMap
                                        : null,
                                    tooltip: l10n.openFullscreenMap,
                                    icon: const Icon(Icons.fullscreen),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              MapLayerToggles(
                                options: _mapLayers,
                                onChanged: (v) =>
                                    setState(() => _mapLayers = v),
                              ),
                              const SizedBox(height: 12),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: full.samples.length >= 2
                                      ? _openFullscreenMap
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 280,
                                    child: IgnorePointer(
                                      child: PilotLineMap(
                                        key: ValueKey(
                                          'map-$_zoomed-$_segStart-$_segEnd-'
                                          '${_mapLayers.showSpeedColors}-'
                                          '${_mapLayers.showRoadKindContrast}-'
                                          '${_mapLayers.showBrakes}',
                                        ),
                                        points: full.samples,
                                        interactive: false,
                                        scrubIndex: mapScrub,
                                        focusStartIndex:
                                            _zoomed ? _segStart : null,
                                        focusEndIndex:
                                            _zoomed ? _segEnd : null,
                                        brakeEvents: full.brakeEvents,
                                        roadStretches: full.roadStretches,
                                        layers: _mapLayers,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        LabSection(
                          title: l10n.sectionRoad,
                          subtitle: l10n.sectionRoadSub,
                          badge: '${a.roadStretches.length}',
                          expanded: _isOpen('road'),
                          onToggle: () => _toggle('road'),
                          child: RoadStretchesPanel(
                            stretches: a.roadStretches,
                            onSelectStretch: _openRoadStretch,
                          ),
                        ),
                        LabSection(
                          title: l10n.sectionBrakes,
                          subtitle: l10n.sectionBrakesSub,
                          badge: '${a.brakeEvents.length}',
                          expanded: _isOpen('brakes'),
                          onToggle: () => _toggle('brakes'),
                          child: BrakeEventsPanel(
                            events: a.brakeEvents,
                            secondsForIndex: a.secondsForIndex,
                            isPro: isPro,
                            onSelectIndex: _setScrubIndex,
                            onZoomToBrake: isPro ? _zoomToBrake : null,
                            onUpgrade: () => showProUpsellSheet(context, ref),
                          ),
                        ),
                        LabSection(
                          title: l10n.sectionCharts,
                          subtitle: l10n.sectionChartsSub,
                          expanded: _isOpen('charts'),
                          onToggle: () => _toggle('charts'),
                          child: Column(
                            children: [
                              SpeedProfileChart(
                                series: a.speedSeries,
                                selectedSeconds: scrubSeconds,
                                onSelectSeconds: _setScrubSeconds,
                                subtitle: _zoomed
                                    ? l10n.chartSpeedSubZoom
                                    : l10n.chartSpeedSub,
                              ),
                              if (a.leanSeries.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                LeanProfileChart(
                                  series: a.leanSeries,
                                  selectedSeconds: scrubSeconds,
                                  onSelectSeconds: _setScrubSeconds,
                                ),
                              ],
                              if (a.accuracySeries.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                RideProfileChart(
                                  title: l10n.gpsPrecision,
                                  subtitle: l10n.gpsPrecisionSub,
                                  series: a.accuracySeries,
                                  lineColor: AppTheme.signal,
                                  unit: 'm',
                                  baselineZero: true,
                                  minY: 0,
                                  selectedSeconds: scrubSeconds,
                                  onSelectSeconds: _setScrubSeconds,
                                ),
                              ],
                            ],
                          ),
                        ),
                        LabSection(
                          title: l10n.sectionNotes,
                          subtitle: isPro
                              ? l10n.sectionNotesSub
                              : l10n.sectionNotesProOnly,
                          badge: isPro ? null : l10n.pro,
                          expanded: _isOpen('notes'),
                          onToggle: () => _toggle('notes'),
                          child: isPro
                              ? Column(
                                  children: [
                                    _PrecisionPanel(analytics: a),
                                    const SizedBox(height: 16),
                                    _InsightStrip(analytics: a),
                                  ],
                                )
                              : ProUpsellBanner(
                                  title: l10n.proNotesBannerTitle,
                                  body: l10n.proNotesBannerBody,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        FreeAdBanner(
          onUpgrade: () => showProUpsellSheet(context, ref),
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
                  minSeconds: a.windowStartSeconds,
                  maxSeconds: a.windowEndSeconds <= a.windowStartSeconds
                      ? a.windowStartSeconds + 1
                      : a.windowEndSeconds,
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
    required this.minSeconds,
    required this.maxSeconds,
    required this.point,
    required this.leanDegrees,
    required this.index,
    required this.totalPoints,
    required this.onChanged,
  });

  final double seconds;
  final double minSeconds;
  final double maxSeconds;
  final TrackPoint point;
  final double leanDegrees;
  final int index;
  final int totalPoints;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final speed = point.speedKmh;
    final side = leanDegrees < -1
        ? l10n.leftShort
        : leanDegrees > 1
            ? l10n.rightShort
            : '·';
    final min = minSeconds;
    final max = maxSeconds <= min ? min + 1 : maxSeconds;

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
                l10n.playhead,
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
          Text.rich(
            TextSpan(
              style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
              children: [
                TextSpan(
                  text:
                      'Point ${index + 1}/$totalPoints  ·  '
                      '${speed == null ? "--" : "${speed.toStringAsFixed(0)} ${l10n.kmh}"}  ·  lean ',
                ),
                TextSpan(
                  text: '${leanDegrees.abs().toStringAsFixed(0)}° $side',
                  style: TextStyle(
                    color: RideVizPalette.leanColor(leanDegrees),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text:
                      '  ·  GPS ${point.accuracyMeters?.toStringAsFixed(1) ?? "--"} m',
                ),
              ],
            ),
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
              value: seconds.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
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
    final l10n = context.l10n;
    final a = analytics;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigStat(
                label: l10n.distance,
                value: a.distanceKm.toStringAsFixed(2),
                unit: 'km',
                accent: AppTheme.line,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStat(
                label: l10n.duration,
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
                label: l10n.maxSpeed,
                value: a.maxSpeedKmh == null
                    ? '--'
                    : a.maxSpeedKmh!.toStringAsFixed(0),
                unit: l10n.kmh,
                accent: a.maxSpeedKmh == null
                    ? AppTheme.steel
                    : RideVizPalette.speedColor(a.maxSpeedKmh!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStat(
                label: l10n.maxLR,
                value: a.leanSides.sampleCount == 0
                    ? '--'
                    : '${a.maxLeanLeft.toStringAsFixed(0)}/${a.maxLeanRight.toStringAsFixed(0)}',
                unit: '°',
                accent: RideVizPalette.leanLeft,
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
    final l10n = context.l10n;
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
                label: l10n.points,
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
                    : '${a.avgMovingSpeedKmh!.toStringAsFixed(0)} ${l10n.kmh}',
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
