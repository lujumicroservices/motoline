import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/curva_analysis.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../pro/pro_upsell.dart';
import 'fullscreen_map_screen.dart';
import 'map_polyline_builder.dart';

/// Swipeable curva coach: metrics + map zoomed to the active turn.
class CurvaDetailScreen extends ConsumerStatefulWidget {
  const CurvaDetailScreen({
    super.key,
    required this.samples,
    required this.analyses,
    required this.initialIndex,
  });

  final List<TrackPoint> samples;
  final List<CurvaAnalysis> analyses;
  final int initialIndex;

  @override
  ConsumerState<CurvaDetailScreen> createState() => _CurvaDetailScreenState();
}

class _CurvaDetailScreenState extends ConsumerState<CurvaDetailScreen> {
  late final PageController _pages;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.analyses.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  CurvaAnalysis get _current => widget.analyses[_index];

  Future<void> _openFullscreenForCurva() async {
    final a = _current;
    await Navigator.of(context).push<FullscreenMapSelection>(
      MaterialPageRoute(
        builder: (_) => FullscreenMapScreen(
          points: widget.samples,
          scrubIndex: a.apexIndex,
          initialFocusStart: a.mapStartIndex,
          initialFocusEnd: a.mapEndIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.analyses.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.curva)),
        body: Center(child: Text(l10n.roadStretchesEmpty)),
      );
    }

    final total = widget.analyses.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.curvaTitle(_index + 1),
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (total > 1)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${_index + 1} / $total',
                  style: GoogleFonts.outfit(color: AppTheme.steel),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.openFullscreenMap,
            onPressed: _openFullscreenForCurva,
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ProTeaserGate(
        bannerTitle: l10n.proCurvaBannerTitle,
        bannerBody: l10n.proCurvaBannerBody,
        teaserMs: 500,
        child: Column(
          children: [
            if (total > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  l10n.curvaSwipeHint,
                  style: GoogleFonts.outfit(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return _CurvaPage(
                    samples: widget.samples,
                    analysis: widget.analyses[i],
                    curvaNumber: i + 1,
                    onZoomLab: () {
                      final a = widget.analyses[i];
                      Navigator.of(context).pop(
                        FullscreenMapSelection(
                          startIndex: a.entryIndex,
                          endIndex: a.exitIndex,
                        ),
                      );
                    },
                    onOpenMap: () async {
                      final a = widget.analyses[i];
                      await Navigator.of(context)
                          .push<FullscreenMapSelection>(
                        MaterialPageRoute(
                          builder: (_) => FullscreenMapScreen(
                            points: widget.samples,
                            scrubIndex: a.apexIndex,
                            initialFocusStart: a.mapStartIndex,
                            initialFocusEnd: a.mapEndIndex,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurvaPage extends StatelessWidget {
  const _CurvaPage({
    required this.samples,
    required this.analysis,
    required this.curvaNumber,
    required this.onZoomLab,
    required this.onOpenMap,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;
  final int curvaNumber;
  final VoidCallback onZoomLab;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = analysis;
    final sideColor = a.stretch.side == TurnSide.izquierda
        ? RideVizPalette.leanLeft
        : a.stretch.side == TurnSide.derecha
            ? RideVizPalette.leanRight
            : AppTheme.lineHot;

    final stretchLabel = switch (a.stretch.kind) {
      RoadKind.recta => l10n.recta,
      RoadKind.curva => a.stretch.side == TurnSide.izquierda
          ? l10n.curvaIzquierda
          : a.stretch.side == TurnSide.derecha
              ? l10n.curvaDerecha
              : l10n.curva,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          stretchLabel,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: sideColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${a.distanceMeters.toStringAsFixed(0)} m · '
          '${formatDuration(a.duration)} · '
          'giro ${a.stretch.headingChangeDeg.abs().toStringAsFixed(0)}° · '
          'lean ${a.stretch.avgAbsLeanDeg.toStringAsFixed(0)}°',
          style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.fullscreen, size: 18),
                label: Text(l10n.curvaOpenMap),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onZoomLab,
                icon: const Icon(Icons.center_focus_strong, size: 18),
                label: Text(l10n.curvaZoomLab),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 300,
          child: _CurvaMap(
            key: ValueKey('curva-map-$curvaNumber-${a.entryIndex}'),
            samples: samples,
            analysis: a,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.curvaMapLegend,
          style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 12),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.curveLine,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PhaseCard(
                letter: 'E',
                title: l10n.entry,
                speedKmh: a.entrySpeedKmh,
                color: RideVizPalette.speedColor(a.entrySpeedKmh),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PhaseCard(
                letter: 'A',
                title: l10n.apex,
                speedKmh: a.apexSpeedKmh,
                color: RideVizPalette.speedColor(a.apexSpeedKmh),
                accent: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PhaseCard(
                letter: 'S',
                title: l10n.exit,
                speedKmh: a.exitSpeedKmh,
                color: RideVizPalette.speedColor(a.exitSpeedKmh),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DeltaRow(
          label: l10n.brakeToApex,
          value: '−${a.speedDropToApexKmh.toStringAsFixed(0)} ${l10n.kmh}',
          positive: false,
        ),
        const SizedBox(height: 8),
        _DeltaRow(
          label: l10n.accelFromApex,
          value: '+${a.speedGainFromApexKmh.toStringAsFixed(0)} ${l10n.kmh}',
          positive: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l10n.leanAtApex,
                value: a.apexLeanDegrees == null
                    ? '--'
                    : '${a.apexLeanDegrees!.abs().toStringAsFixed(0)}°',
                hint: a.apexLeanDegrees == null
                    ? null
                    : (a.apexLeanDegrees! < 0
                        ? l10n.leftShort
                        : l10n.rightShort),
                color: a.apexLeanDegrees == null
                    ? AppTheme.steel
                    : RideVizPalette.leanColor(a.apexLeanDegrees!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: l10n.maxLean,
                value: '${a.maxLeanDegrees.toStringAsFixed(0)}°',
                color: sideColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.curvaCoach,
          style: GoogleFonts.outfit(
            color: AppTheme.steel,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.letter,
    required this.title,
    required this.speedKmh,
    required this.color,
    this.accent = false,
  });

  final String letter;
  final String title;
  final double speedKmh;
  final Color color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent
              ? color.withValues(alpha: 0.8)
              : AppTheme.mist.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              letter,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                color: AppTheme.asphalt,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 11),
          ),
          Text(
            speedKmh.toStringAsFixed(0),
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          Text(
            context.l10n.kmh,
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.label,
    required this.value,
    required this.positive,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? RideVizPalette.leanLeft : RideVizPalette.brakeHard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.outfit(fontSize: 14)),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.hint,
  });

  final String label;
  final String value;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              letterSpacing: 1.0,
              color: AppTheme.steel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    hint!,
                    style: GoogleFonts.outfit(
                      color: AppTheme.steel,
                      fontSize: 12,
                    ),
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

class _CurvaMap extends StatefulWidget {
  const _CurvaMap({
    super.key,
    required this.samples,
    required this.analysis,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;

  @override
  State<_CurvaMap> createState() => _CurvaMapState();
}

class _CurvaMapState extends State<_CurvaMap> {
  final MapController _map = MapController();

  @override
  void didUpdateWidget(covariant _CurvaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.analysis.entryIndex != widget.analysis.entryIndex ||
        oldWidget.analysis.exitIndex != widget.analysis.exitIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  void _fit() {
    final a = widget.analysis;
    final focus = widget.samples.sublist(a.entryIndex, a.exitIndex + 1);
    if (focus.length < 2) return;
    final bounds = LatLngBounds.fromPoints([
      for (final p in focus) LatLng(p.latitude, p.longitude),
    ]);
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
          maxZoom: 19,
        ),
      );
    } catch (_) {
      // Map not ready yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    final samples = widget.samples;
    final analysis = widget.analysis;
    final lo = analysis.mapStartIndex;
    final hi = analysis.mapEndIndex;
    if (hi - lo < 1) {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.asphaltElevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          context.l10n.noGpsPoints,
          style: const TextStyle(color: AppTheme.steel),
        ),
      );
    }

    final focus = samples.sublist(analysis.entryIndex, analysis.exitIndex + 1);
    final bounds = LatLngBounds.fromPoints([
      for (final p in focus) LatLng(p.latitude, p.longitude),
    ]);

    final polylines = <Polyline>[];
    if (analysis.entryIndex > lo) {
      polylines.add(
        Polyline(
          points: [
            for (final p in samples.sublist(lo, analysis.entryIndex + 1))
              LatLng(p.latitude, p.longitude),
          ],
          color: AppTheme.steel.withValues(alpha: 0.35),
          strokeWidth: 3,
        ),
      );
    }
    polylines.addAll(
      buildMergedStyledPolylines(
        segment: samples.sublist(analysis.entryIndex, analysis.exitIndex + 1),
        indexOffset: analysis.entryIndex,
        kindByIndex: List.filled(samples.length, null),
        showRoadKindContrast: false,
        showSpeedColors: true,
      ),
    );
    if (analysis.exitIndex < hi) {
      polylines.add(
        Polyline(
          points: [
            for (final p in samples.sublist(analysis.exitIndex, hi + 1))
              LatLng(p.latitude, p.longitude),
          ],
          color: AppTheme.steel.withValues(alpha: 0.35),
          strokeWidth: 3,
        ),
      );
    }

    Marker pin(int index, String letter, Color color) {
      final p = samples[index];
      return Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 30,
        height: 30,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.mist, width: 2),
          ),
          child: Text(
            letter,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppTheme.asphalt,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(40),
            maxZoom: 19,
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.motoline.motoline',
          ),
          PolylineLayer(polylines: polylines),
          MarkerLayer(
            markers: [
              pin(
                analysis.entryIndex,
                'E',
                RideVizPalette.speedColor(analysis.entrySpeedKmh),
              ),
              pin(
                analysis.apexIndex,
                'A',
                RideVizPalette.speedColor(analysis.apexSpeedKmh),
              ),
              pin(
                analysis.exitIndex,
                'S',
                RideVizPalette.speedColor(analysis.exitSpeedKmh),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
