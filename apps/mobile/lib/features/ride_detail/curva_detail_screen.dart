import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/curva_analysis.dart';
import '../../core/analytics/road_kind_detection.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

/// Zoomed map + entrada / ápice / salida metrics for one curva.
class CurvaDetailScreen extends StatelessWidget {
  const CurvaDetailScreen({
    super.key,
    required this.samples,
    required this.analysis,
    required this.curvaNumber,
  });

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;
  final int curvaNumber;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.curvaTitle(curvaNumber),
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
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
            'giro ${a.stretch.headingChangeDeg.abs().toStringAsFixed(0)}°',
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: _CurvaMap(samples: samples, analysis: a),
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
      ),
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
              ? color.withValues(alpha: 0.7)
              : color.withValues(alpha: 0.25),
          width: accent ? 2 : 1,
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
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppTheme.steel,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            speedKmh.toStringAsFixed(0),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          Text(
            context.l10n.kmh,
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.steel),
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
          Text(label, style: GoogleFonts.outfit(color: AppTheme.steel)),
          const Spacer(),
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
  final String? hint;
  final Color color;

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

class _CurvaMap extends StatelessWidget {
  const _CurvaMap({required this.samples, required this.analysis});

  final List<TrackPoint> samples;
  final CurvaAnalysis analysis;

  @override
  Widget build(BuildContext context) {
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
    for (var i = analysis.entryIndex + 1; i <= analysis.exitIndex; i++) {
      final a = samples[i - 1];
      final b = samples[i];
      final speed = b.speedKmh ?? a.speedKmh ?? 0;
      polylines.add(
        Polyline(
          points: [
            LatLng(a.latitude, a.longitude),
            LatLng(b.latitude, b.longitude),
          ],
          color: RideVizPalette.speedColor(speed),
          strokeWidth: 6,
        ),
      );
    }
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
