import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/brake_detection.dart';
import '../../core/analytics/curva_analysis.dart';
import '../../core/features.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/ride.dart';
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
import 'ride_rename.dart';
import 'skill_lab_screen.dart';
import 'widgets/brake_events_panel.dart';
import 'widgets/gps_quality_chip.dart';
import 'widgets/lab_section.dart';
import 'widgets/map_layer_toggles.dart';
import 'widgets/motorcycle_lean_gauge.dart';
import 'widgets/ride_loop_panel.dart';
import 'widgets/ride_profile_chart.dart';
import 'widgets/ride_share_panel.dart';
import 'widgets/ride_skill_coach_card.dart';
import 'widgets/road_stretches_panel.dart';

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
    'loop',
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

  Future<void> _renameOrGeocodeRide(Ride ride) async {
    await showRideRenameDialog(context, ref, ride);
  }

  Future<void> _confirmDeleteRide() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRide),
        content: Text(l10n.deleteRideBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.signal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final rideId = widget.rideId;
    await ref.read(rideSyncServiceProvider).deleteRideEverywhere(rideId);
    ref.invalidate(ridesListProvider);
    ref.invalidate(rideProvider(rideId));
    if (widget.analytics.ride.routeId != null) {
      ref.invalidate(ridesForRouteProvider(widget.analytics.ride.routeId!));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.rideDeleted)),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
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
      _expanded.addAll({'map', 'brakes', 'overview'});
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

    final result = await Navigator.of(context).push<Object?>(
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
    if (result is int) {
      final abs = result.clamp(0, full.samples.length - 1);
      setState(() {
        if (_zoomed) {
          _scrubIndex = (abs - _segStart).clamp(0, _segEnd - _segStart);
        } else {
          _scrubIndex = abs;
        }
      });
      return;
    }
    if (result is! FullscreenMapSelection) return;
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
      _expanded.addAll({'overview', 'map'});
    });
  }

  Future<void> _openRoadStretch(int stretchIndex) async {
    final a = _view;
    if (stretchIndex < 0 || stretchIndex >= a.roadStretches.length) return;
    final stretch = a.roadStretches[stretchIndex];
    if (stretch.kind != RoadKind.curva) return;

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
      _expanded.addAll({'overview', 'map'});
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
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    tooltip: l10n.deleteRide,
                    icon: const Icon(Icons.delete_outline),
                    color: AppTheme.signal,
                    onPressed: _confirmDeleteRide,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
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
                          ride.displayTitle(
                            dateFormat: (d) => DateFormat(
                              'EEE · MMM d · HH:mm',
                              l10n.localeName,
                            ).format(d),
                          ),
                          style: GoogleFonts.exo2(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (ride.title != null &&
                            ride.title!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'EEE · MMM d · HH:mm',
                              l10n.localeName,
                            ).format(ride.startedAt),
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 15,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          _zoomed ? l10n.segmentZoomHint : l10n.collapseHint,
                          style: GoogleFonts.rajdhani(
                            color: AppTheme.steel,
                            fontSize: 15,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _renameOrGeocodeRide(ride),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              ride.title == null || ride.title!.isEmpty
                                  ? l10n.nameFromMap
                                  : l10n.renameRide,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GpsQualityChip(analytics: full),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (AppFeatures.routesEnabled)
                              CompareLocalRouteEntry(ride: ride),
                            ComparePeersEntry(localRideId: ride.id),
                          ],
                        ),
                        const SizedBox(height: 12),
                        RideSkillCoachCard(
                          summary: a.skillSummary,
                          onOpenLab: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SkillLabScreen(
                                  samples: full.samples,
                                  summary: full.skillSummary,
                                  neutralLeanDegrees: full.neutralLeanDegrees,
                                  brakeEvents: full.brakeEvents,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        RideSharePanel(ride: ride),
                        const SizedBox(height: 16),
                        LabSection(
                          title: l10n.sectionOverview,
                          subtitle: _zoomed
                              ? l10n.sectionOverviewSubZoom
                              : l10n.sectionOverviewSub,
                          expanded: _isOpen('overview'),
                          onToggle: () => _toggle('overview'),
                          child: _MetricGrid(analytics: a),
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
                                  neutralLabel: l10n.leanAtPlayhead(
                                    a.neutralLeanDegrees.toStringAsFixed(0),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  l10n.leanHelp,
                                  style: GoogleFonts.rajdhani(
                                    color: AppTheme.steel,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.leanPhoneDisclaimer,
                                  style: GoogleFonts.rajdhani(
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
                                      style: GoogleFonts.rajdhani(
                                        color: AppTheme.steel,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (_zoomed) ...[
                                    TextButton(
                                      onPressed: _clearSegmentZoom,
                                      child: Text(l10n.fullRide),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: SizedBox(
                                  height: 280,
                                  child: PilotLineMap(
                                    key: ValueKey(
                                      'map-$_zoomed-$_segStart-$_segEnd-'
                                      '${_mapLayers.showSpeedColors}-'
                                      '${_mapLayers.showRoadKindContrast}-'
                                      '${_mapLayers.showBrakes}',
                                    ),
                                    points: full.samples,
                                    interactive: true,
                                    scrubIndex: mapScrub,
                                    onTapScrub: (absIndex) {
                                      if (_zoomed) {
                                        _setScrubIndex(absIndex - _segStart);
                                      } else {
                                        _setScrubIndex(absIndex);
                                      }
                                    },
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
                            ],
                          ),
                        ),
                        if (AppFeatures.routesEnabled)
                          LabSection(
                            title: l10n.sectionLoop,
                            subtitle: l10n.sectionLoopSub,
                            expanded: _isOpen('loop'),
                            onToggle: () => _toggle('loop'),
                            child: RideLoopPanel(
                              ride: ride,
                              points: full.samples,
                            ),
                          ),
                        LabSection(
                          title: l10n.sectionRoad,
                          subtitle: l10n.sectionRoadSub,
                          badge:
                              '${a.roadStretches.where((s) => s.kind == RoadKind.curva).length}',
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
                              ? _PrecisionPanel(analytics: a)
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
    final speedLabel = speed == null
        ? '--'
        : '${speed.toStringAsFixed(0)} ${l10n.kmh}';

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
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.lineHot,
                ),
              ),
              const Spacer(),
              Text(
                _fmt(seconds),
                style: GoogleFonts.exo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
              children: [
                TextSpan(
                  text: l10n.scrubPointMeta(
                    index + 1,
                    totalPoints,
                    speedLabel,
                  ),
                ),
                TextSpan(
                  text: '${leanDegrees.abs().toStringAsFixed(0)}° $side',
                  style: TextStyle(
                    color: RideVizPalette.leanColor(leanDegrees),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: l10n.scrubGpsMeta(
                    point.accuracyMeters?.toStringAsFixed(1) ?? '--',
                  ),
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
                unit: 'Â°',
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
            style: GoogleFonts.rajdhani(
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
                  style: GoogleFonts.exo2(
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniPill(label: l10n.points, value: '${a.samples.length}'),
        _MiniPill(
          label: 'Hz',
          value: a.sampleRateHz == null
              ? '--'
              : a.sampleRateHz!.toStringAsFixed(1),
        ),
        _MiniPill(
          label: 'GPS',
          value: a.avgGpsAccuracyM == null
              ? '--'
              : '${a.avgGpsAccuracyM!.toStringAsFixed(1)} m',
        ),
      ],
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
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              letterSpacing: 0.9,
              color: AppTheme.steel,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
