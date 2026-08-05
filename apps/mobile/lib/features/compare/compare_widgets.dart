import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/analytics/track_segment_align.dart';
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
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rightLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
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
              style: GoogleFonts.exo2(
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
              style: GoogleFonts.exo2(
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

/// Two polylines on one map (baseline cyan solid, challenger amber dashed).
///
/// Near-identical GPS paths are separated with a small lateral offset so both
/// lines stay readable. Prefer [fromTrackPoints] with [sharedCorridorOnly] so
/// the map zooms to the comparable road section.
class DualPolylineMap extends StatelessWidget {
  const DualPolylineMap({
    super.key,
    required this.left,
    required this.right,
    required this.leftLabel,
    required this.rightLabel,
    this.caption,
    this.leftPlayhead,
    this.rightPlayhead,
  });

  final List<LatLng> left;
  final List<LatLng> right;
  final String leftLabel;
  final String rightLabel;
  final String? caption;
  final LatLng? leftPlayhead;
  final LatLng? rightPlayhead;

  factory DualPolylineMap.fromTrackPoints({
    Key? key,
    required List<TrackPoint> left,
    required List<TrackPoint> right,
    required String leftLabel,
    required String rightLabel,
    bool sharedCorridorOnly = true,
    String? caption,
    LatLng? leftPlayhead,
    LatLng? rightPlayhead,
  }) {
    var l = left;
    var r = right;
    String? autoCaption = caption;
    if (sharedCorridorOnly) {
      final aligned = alignSharedCorridor(left, right);
      if (aligned != null && aligned.isUsable) {
        l = aligned.left;
        r = aligned.right;
        autoCaption ??= caption;
      }
    }
    return DualPolylineMap(
      key: key,
      left: [for (final p in l) LatLng(p.latitude, p.longitude)],
      right: [for (final p in r) LatLng(p.latitude, p.longitude)],
      leftLabel: leftLabel,
      rightLabel: rightLabel,
      caption: autoCaption,
      leftPlayhead: leftPlayhead,
      rightPlayhead: rightPlayhead,
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawLeft = left.length >= 2 ? _offsetPath(left, -3.5) : left;
    final drawRight = right.length >= 2 ? _offsetPath(right, 3.5) : right;
    final all = [
      ...drawLeft,
      ...drawRight,
      ?leftPlayhead,
      ?rightPlayhead,
    ];
    if (all.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          context.l10n.compareTrackUnavailable,
          style: GoogleFonts.rajdhani(color: AppTheme.steel),
        ),
      );
    }
    final bounds = LatLngBounds.fromPoints(all);
    final bothOk = drawLeft.length >= 2 && drawRight.length >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(RideVizPalette.leanLeft, leftLabel, solid: true),
            const SizedBox(width: 16),
            _legendDot(RideVizPalette.leanRight, rightLabel, solid: false),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 6),
          Text(
            caption!,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
        if (!bothOk) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.compareOneTrackOnly,
            style: GoogleFonts.rajdhani(
              color: AppTheme.lineHot,
              fontSize: 12,
            ),
          ),
        ],
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
                    if (drawLeft.length >= 2)
                      Polyline(
                        points: drawLeft,
                        strokeWidth: 5.5,
                        borderStrokeWidth: 2.5,
                        borderColor: Colors.black.withValues(alpha: 0.55),
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.95),
                      ),
                    if (drawRight.length >= 2)
                      Polyline(
                        points: drawRight,
                        strokeWidth: 5,
                        borderStrokeWidth: 2,
                        borderColor: Colors.black.withValues(alpha: 0.45),
                        color: RideVizPalette.leanRight.withValues(alpha: 0.95),
                        pattern: StrokePattern.dashed(
                          segments: <double>[14, 10],
                        ),
                      ),
                  ],
                ),
                if (leftPlayhead != null || rightPlayhead != null)
                  MarkerLayer(
                    markers: [
                      if (leftPlayhead != null)
                        Marker(
                          point: leftPlayhead!,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: RideVizPalette.leanLeft,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      if (rightPlayhead != null)
                        Marker(
                          point: rightPlayhead!,
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: RideVizPalette.leanRight,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
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

  Widget _legendDot(Color color, String label, {required bool solid}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: solid ? 18 : 18,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: solid
                ? null
                : Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: solid
              ? null
              : CustomPaint(painter: _DashLegendPainter(color)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.steel, fontSize: 12)),
      ],
    );
  }
}

class _DashLegendPainter extends CustomPainter {
  _DashLegendPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height / 2), Offset(7, size.height / 2), paint);
    canvas.drawLine(
      Offset(11, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DashLegendPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Nudge a path ~[meters] to the right of travel so stacked GPS lines separate.
List<LatLng> _offsetPath(List<LatLng> pts, double meters) {
  if (pts.length < 2 || meters.abs() < 0.1) return pts;
  const earth = 6371000.0;
  final out = <LatLng>[];
  for (var i = 0; i < pts.length; i++) {
    final prev = pts[i > 0 ? i - 1 : 0];
    final next = pts[i < pts.length - 1 ? i + 1 : i];
    final lat1 = prev.latitude * math.pi / 180;
    final lat2 = next.latitude * math.pi / 180;
    final dLon = (next.longitude - prev.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x) + math.pi / 2;
    final lat = pts[i].latitude * math.pi / 180;
    final lon = pts[i].longitude * math.pi / 180;
    final ang = meters / earth;
    final nLat = math.asin(
      math.sin(lat) * math.cos(ang) +
          math.cos(lat) * math.sin(ang) * math.cos(bearing),
    );
    final nLon = lon +
        math.atan2(
          math.sin(bearing) * math.sin(ang) * math.cos(lat),
          math.cos(ang) - math.sin(lat) * math.sin(nLat),
        );
    out.add(LatLng(nLat * 180 / math.pi, nLon * 180 / math.pi));
  }
  return out;
}

