import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

/// Normalized metrics for side-by-side compare (local or cloud).
class CompareRideMetrics {
  const CompareRideMetrics({
    required this.distanceKm,
    required this.duration,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.maxLeanLeft,
    required this.maxLeanRight,
    required this.lineScore,
  });

  final double distanceKm;
  final Duration duration;
  final double? maxSpeedKmh;
  final double? avgSpeedKmh;
  final double? maxLeanLeft;
  final double? maxLeanRight;
  final int? lineScore;

  factory CompareRideMetrics.fromAnalytics(RideAnalytics a) =>
      CompareRideMetrics(
        distanceKm: a.distanceKm,
        duration: a.duration,
        maxSpeedKmh: a.maxSpeedKmh,
        avgSpeedKmh: a.ride.avgSpeedKmh,
        maxLeanLeft: a.maxLeanLeft,
        maxLeanRight: a.maxLeanRight,
        lineScore: a.lineScore,
      );

  factory CompareRideMetrics.fromCloud(CloudRideSummary r) =>
      CompareRideMetrics(
        distanceKm: r.distanceKm,
        duration: r.duration,
        maxSpeedKmh: r.maxSpeedKmh,
        avgSpeedKmh: r.avgSpeedKmh,
        maxLeanLeft: r.maxLeanLeftDeg,
        maxLeanRight: r.maxLeanRightDeg,
        lineScore: r.lineScore,
      );
}

/// Side-by-side metric table. Highlights the better value when [highlightBest].
class CompareMetricsTable extends StatelessWidget {
  const CompareMetricsTable({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.left,
    required this.right,
    this.highlightBest = true,
  });

  final String leftLabel;
  final String rightLabel;
  final CompareRideMetrics left;
  final CompareRideMetrics right;
  final bool highlightBest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leftLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rightLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(
            l10n.distance,
            _fmtKm(left.distanceKm),
            _fmtKm(right.distanceKm),
            winner: _nearEqual(left.distanceKm, right.distanceKm)
                ? null
                : (left.distanceKm < right.distanceKm ? 0 : 1),
          ),
          _row(
            l10n.duration,
            formatDuration(left.duration),
            formatDuration(right.duration),
            winner: left.duration == right.duration
                ? null
                : (left.duration < right.duration ? 0 : 1),
          ),
          _row(
            l10n.maxSpeed,
            _fmtSpeed(left.maxSpeedKmh, l10n.kmh),
            _fmtSpeed(right.maxSpeedKmh, l10n.kmh),
            winner: _winnerHigher(left.maxSpeedKmh, right.maxSpeedKmh),
          ),
          _row(
            l10n.avgSpeed,
            _fmtSpeed(left.avgSpeedKmh, l10n.kmh),
            _fmtSpeed(right.avgSpeedKmh, l10n.kmh),
            winner: _winnerHigher(left.avgSpeedKmh, right.avgSpeedKmh),
          ),
          _row(
            l10n.maxLR,
            _fmtLean(left.maxLeanLeft, left.maxLeanRight),
            _fmtLean(right.maxLeanLeft, right.maxLeanRight),
            winner: null,
          ),
          _row(
            l10n.lineScore,
            '${left.lineScore ?? "—"}',
            '${right.lineScore ?? "—"}',
            winner: _winnerHigher(
              left.lineScore?.toDouble(),
              right.lineScore?.toDouble(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String leftText,
    String rightText, {
    int? winner,
  }) {
    final leftWin = highlightBest && winner == 0;
    final rightWin = highlightBest && winner == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              leftText,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: leftWin ? RideVizPalette.leanLeft : null,
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.steel, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              rightText,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: rightWin ? RideVizPalette.leanRight : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _nearEqual(double a, double b) => (a - b).abs() < 0.02;

  int? _winnerHigher(double? a, double? b) {
    if (a == null && b == null) return null;
    if (a == null) return 1;
    if (b == null) return 0;
    if ((a - b).abs() < 0.05) return null;
    return a > b ? 0 : 1;
  }

  String _fmtKm(double km) => '${km.toStringAsFixed(2)} km';
  String _fmtSpeed(double? v, String unit) =>
      v == null ? '—' : '${v.toStringAsFixed(0)} $unit';
  String _fmtLean(double? l, double? r) =>
      '${l?.toStringAsFixed(0) ?? "—"}° / ${r?.toStringAsFixed(0) ?? "—"}°';
}

/// Two polylines on one map (baseline cyan, challenger amber).
class DualPolylineMap extends StatelessWidget {
  const DualPolylineMap({
    super.key,
    required this.left,
    required this.right,
    required this.leftLabel,
    required this.rightLabel,
  });

  final List<LatLng> left;
  final List<LatLng> right;
  final String leftLabel;
  final String rightLabel;

  factory DualPolylineMap.fromTrackPoints({
    Key? key,
    required List<TrackPoint> left,
    required List<TrackPoint> right,
    required String leftLabel,
    required String rightLabel,
  }) {
    return DualPolylineMap(
      key: key,
      left: [for (final p in left) LatLng(p.latitude, p.longitude)],
      right: [for (final p in right) LatLng(p.latitude, p.longitude)],
      leftLabel: leftLabel,
      rightLabel: rightLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [...left, ...right];
    if (all.length < 2) return const SizedBox.shrink();
    final bounds = LatLngBounds.fromPoints(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(RideVizPalette.leanLeft, leftLabel),
            const SizedBox(width: 16),
            _legendDot(RideVizPalette.leanRight, rightLabel),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(36),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                PolylineLayer(
                  polylines: [
                    if (left.length >= 2)
                      Polyline(
                        points: left,
                        strokeWidth: 4,
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.9),
                      ),
                    if (right.length >= 2)
                      Polyline(
                        points: right,
                        strokeWidth: 4,
                        color: RideVizPalette.leanRight.withValues(alpha: 0.9),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.steel, fontSize: 12)),
      ],
    );
  }
}
