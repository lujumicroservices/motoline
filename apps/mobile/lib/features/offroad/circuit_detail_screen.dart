import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_model.dart';
import 'offroad_home_screen.dart' show CircuitStat;
import 'track_3d_screen.dart';
import 'widgets/circuit_silhouette.dart';

/// Explore what the mapping captured: 2D map, relief, sectors, mapping data.
class CircuitDetailScreen extends StatelessWidget {
  const CircuitDetailScreen({super.key, required this.circuit});

  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(circuit.name),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.circuitTabMap),
              Tab(text: l10n.circuitTabRelief),
              Tab(text: l10n.circuitTabSectors),
              Tab(text: l10n.circuitTabMapping),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MapTab(circuit: circuit),
            _ReliefTab(circuit: circuit),
            _SectorsTab(circuit: circuit),
            _MappingTab(circuit: circuit),
          ],
        ),
      ),
    );
  }
}

enum _BaseLayer { satellite, relief, topo }

class _MapTab extends StatefulWidget {
  const _MapTab({required this.circuit});
  final Circuit circuit;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  var _layer = _BaseLayer.satellite;

  TileLayer _tiles() {
    switch (_layer) {
      case _BaseLayer.satellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          maxNativeZoom: 19,
          userAgentPackageName: 'com.rawthrottle.riderlab',
        );
      case _BaseLayer.relief:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/Elevation/World_Hillshade_Dark/MapServer/tile/{z}/{y}/{x}',
          maxNativeZoom: 16,
          userAgentPackageName: 'com.rawthrottle.riderlab',
        );
      case _BaseLayer.topo:
        return TileLayer(
          urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
          maxNativeZoom: 17,
          userAgentPackageName: 'com.rawthrottle.riderlab',
        );
    }
  }

  String get _attribution => switch (_layer) {
    _BaseLayer.satellite => 'Esri World Imagery',
    _BaseLayer.relief => 'Esri World Hillshade',
    _BaseLayer.topo => '© OpenTopoMap (CC-BY-SA) · © OpenStreetMap',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.circuit;
    final lines = c.sectorLines();
    final bounds = LatLngBounds.fromPoints(c.outer);
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 40),
            ),
            maxZoom: 21,
            backgroundColor: OffroadTheme.field,
          ),
          children: [
            _tiles(),
            PolygonLayer(
              polygons: [
                Polygon(
                  points: c.outer,
                  holePointsList: [c.inner],
                  color: OffroadTheme.track.withValues(alpha: 0.55),
                  borderColor: OffroadTheme.outline,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            PolylineLayer(
              polylines: [
                for (var i = 0; i < lines.length; i++)
                  if (lines[i].length > 1)
                    Polyline(
                      points: lines[i],
                      color: OffroadTheme.sector(i),
                      strokeWidth: 3,
                      borderColor: OffroadTheme.outline,
                      borderStrokeWidth: 1.5,
                    ),
                for (final g in c.gates)
                  Polyline(
                    points: [g.a, g.b],
                    color: g.kind == 0 ? Colors.white : OffroadTheme.textFaint,
                    strokeWidth: 3,
                    borderColor: OffroadTheme.outline,
                    borderStrokeWidth: 1.5,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                ..._arrows(c),
                Marker(
                  point: c.anchor,
                  width: 40,
                  height: 40,
                  child: const _FlagBadge(),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Wrap(
            spacing: 8,
            children: [
              for (final l in _BaseLayer.values)
                ChoiceChip(
                  label: Text(switch (l) {
                    _BaseLayer.satellite => l10n.circuitLayerSatellite,
                    _BaseLayer.relief => l10n.circuitLayerRelief,
                    _BaseLayer.topo => l10n.circuitLayerTopo,
                  }),
                  selected: _layer == l,
                  onSelected: (_) => setState(() => _layer = l),
                  selectedColor: OffroadTheme.track,
                  backgroundColor: OffroadTheme.panel.withValues(alpha: 0.9),
                  labelStyle: TextStyle(
                    color: _layer == l ? Colors.black : OffroadTheme.text,
                    fontWeight: FontWeight.w700,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 30,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Track3DScreen(circuit: c),
              ),
            ),
            icon: const Icon(Icons.view_in_ar_rounded),
            label: Text(l10n.pass3dOpen),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.black54,
            child: Text(
              _attribution,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }

  /// Direction-of-travel arrows every ~120 m along the centerline.
  List<Marker> _arrows(Circuit c) {
    const step = 120.0;
    const d = Distance();
    final out = <Marker>[];
    var next = step / 2;
    for (var i = 0; i < c.center.length; i++) {
      if (c.centerCum[i] < next) continue;
      final a = c.center[i];
      final b = c.center[(i + 1) % c.center.length];
      final bearing = d.bearing(a, b) * math.pi / 180;
      out.add(
        Marker(
          point: a,
          width: 22,
          height: 22,
          child: Transform.rotate(
            angle: bearing,
            child: const Icon(
              Icons.navigation_rounded,
              size: 20,
              color: OffroadTheme.outline,
              shadows: [Shadow(color: OffroadTheme.track, blurRadius: 3)],
            ),
          ),
        ),
      );
      next += step;
    }
    return out;
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OffroadTheme.outline,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.sports_score_rounded, color: Colors.white, size: 22),
    );
  }
}

class _ReliefTab extends StatelessWidget {
  const _ReliefTab({required this.circuit});
  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = circuit;
    var climb = 0.0;
    for (var i = 1; i < c.elevation.length; i++) {
      final dz = c.elevation[i] - c.elevation[i - 1];
      if (dz > 0) climb += dz;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircuitStat(
              value: c.elevDrop.toStringAsFixed(1),
              unit: 'm',
              label: l10n.circuitStatDrop,
            ),
            CircuitStat(
              value: climb.toStringAsFixed(0),
              unit: 'm',
              label: l10n.circuitStatClimb,
            ),
            CircuitStat(
              value: c.elevMin.toStringAsFixed(0),
              unit: 'm',
              label: l10n.circuitStatElevMin,
            ),
            CircuitStat(
              value: c.elevMax.toStringAsFixed(0),
              unit: 'm',
              label: l10n.circuitStatElevMax,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.circuitElevationTitle,
          style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 240, child: _ElevationChart(circuit: c)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          children: [
            for (var i = 0; i < c.sectors.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 4,
                    color: OffroadTheme.sector(i),
                  ),
                  const SizedBox(width: 6),
                  Text(c.sectors[i].name, style: OffroadTheme.label()),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.circuitElevationNote(c.elevSource),
          style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
        ),
      ],
    );
  }
}

class _ElevationChart extends StatelessWidget {
  const _ElevationChart({required this.circuit});
  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final c = circuit;
    final bars = <LineChartBarData>[];
    for (var k = 0; k < c.sectors.length; k++) {
      final s = c.sectors[k];
      final spots = <FlSpot>[
        for (var i = 0; i < c.elevation.length; i++)
          if (i * c.elevStepM >= s.startM - c.elevStepM &&
              i * c.elevStepM <= s.endM)
            FlSpot(math.min(i * c.elevStepM, c.lengthM), c.elevation[i]),
      ];
      final color = OffroadTheme.sector(k);
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.18),
          ),
        ),
      );
    }
    final minY = (c.elevMin - 2).floorToDouble();
    final maxY = (c.elevMax + 2).ceilToDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: c.lengthM,
        minY: minY,
        maxY: maxY,
        lineBarsData: bars,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: OffroadTheme.panelBorder, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: const TextStyle(fontSize: 11, color: OffroadTheme.textFaint),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 200,
              getTitlesWidget: (v, _) => Text(
                '${v.toStringAsFixed(0)} m',
                style: const TextStyle(fontSize: 11, color: OffroadTheme.textFaint),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => OffroadTheme.panel,
            getTooltipItems: (items) => [
              for (final it in items)
                LineTooltipItem(
                  '${it.x.toStringAsFixed(0)} m · ${it.y.toStringAsFixed(1)} m',
                  OffroadTheme.label(color: OffroadTheme.text),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectorsTab extends StatelessWidget {
  const _SectorsTab({required this.circuit});
  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = circuit;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: c.sectors.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final s = c.sectors[i];
        final color = OffroadTheme.sector(i);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 170,
                color: OffroadTheme.field,
                padding: const EdgeInsets.all(10),
                child: CircuitSilhouette(circuit: c, highlight: i),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                              OffroadTheme.radiusSm,
                            ),
                          ),
                          child: Text(
                            s.name,
                            style: OffroadTheme.hud(20, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${s.startM.toStringAsFixed(0)} – ${s.endM.toStringAsFixed(0)} m',
                          style: OffroadTheme.label(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        CircuitStat(
                          value: s.lengthM.toStringAsFixed(0),
                          unit: 'm',
                          label: l10n.sectorLength,
                          size: 26,
                        ),
                        CircuitStat(
                          value:
                              '${s.widthMin.toStringAsFixed(1)}–${s.widthMax.toStringAsFixed(1)}',
                          unit: 'm',
                          label: l10n.sectorWidth(
                            s.widthMedian.toStringAsFixed(1),
                          ),
                          size: 26,
                        ),
                        if (s.elevMin != null && s.elevMax != null)
                          CircuitStat(
                            value: (s.elevMax! - s.elevMin!).toStringAsFixed(1),
                            unit: 'm',
                            label: l10n.circuitStatDrop,
                            size: 26,
                          ),
                      ],
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

class _MappingTab extends StatelessWidget {
  const _MappingTab({required this.circuit});
  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = circuit;
    final sm = c.smoothing;
    final date = DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(c.mappedOn);
    String edge(String e) =>
        e == 'outer' ? l10n.mappingEdgeOuter : l10n.mappingEdgeInner;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: l10n.mappingSurvey,
          rows: [
            (l10n.mappingDate, date),
            for (final lg in c.loggers) ('${l10n.mappingLogger} ${lg.id}', edge(lg.edge)),
            (l10n.mappingReceiver, c.receiver),
            (
              l10n.mappingAnchor,
              '${c.anchor.latitude.toStringAsFixed(6)}, '
                  '${c.anchor.longitude.toStringAsFixed(6)} · ${c.anchorAlt.toStringAsFixed(0)} m',
            ),
            (
              l10n.mappingDirection,
              c.ccw ? l10n.circuitDirectionCcw : l10n.circuitDirectionCw,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: l10n.mappingSmoothing,
          subtitle: l10n.mappingSmoothingMethod(
            sm.outlierM.toStringAsFixed(0),
            sm.resampleM.toStringAsFixed(1),
          ),
          rows: [
            (
              l10n.mappingMaxDev,
              '${sm.maxDevOuter.toStringAsFixed(2)} / ${sm.maxDevInner.toStringAsFixed(2)} m',
            ),
            (
              l10n.mappingRms,
              '${sm.rmsOuter.toStringAsFixed(2)} / ${sm.rmsInner.toStringAsFixed(2)} m',
            ),
            (l10n.mappingSelfIntersections, '${sm.selfIntersections}'),
            (l10n.mappingInnerInside, '${sm.innerInsidePct.toStringAsFixed(0)} %'),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: l10n.mappingGeometry,
          rows: [
            (l10n.circuitStatLap, '${c.lengthM.toStringAsFixed(1)} m'),
            (
              l10n.circuitStatWidth,
              '${c.widthMin.toStringAsFixed(1)}–${c.widthMax.toStringAsFixed(1)} m '
                  '(${l10n.mappingMedian} ${c.widthMedian.toStringAsFixed(1)} m)',
            ),
            (
              l10n.circuitStatSectors,
              c.sectors.map((s) => s.lengthM.toStringAsFixed(1)).join(' / '),
            ),
            (
              l10n.mappingPoints,
              '${c.outer.length} / ${c.inner.length} / ${c.center.length}',
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows, this.subtitle});

  final String title;
  final String? subtitle;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(k, style: OffroadTheme.label()),
                    ),
                    Expanded(
                      flex: 6,
                      child: Text(
                        v,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: OffroadTheme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
