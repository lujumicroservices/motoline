import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/track_point.dart';
import '../../theme/ride_viz_palette.dart';

class ReelPhoto {
  const ReelPhoto({
    required this.bytes,
    this.latitude,
    this.longitude,
    this.takenAt,
  });

  final Uint8List bytes;
  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
}

class ReelTrailPoint {
  const ReelTrailPoint({
    required this.lat,
    required this.lng,
    required this.leanAbs,
    this.speedKmh,
  });

  final double lat;
  final double lng;
  final double leanAbs;
  final double? speedKmh;
}

class ReelHighlights {
  const ReelHighlights({
    required this.title,
    required this.destination,
    required this.distanceKm,
    required this.maxLeanDeg,
    required this.curveCount,
    required this.riderCount,
    required this.duration,
    required this.trail,
    required this.photos,
    this.maxSpeedKmh,
    this.hookKind = 'lean',
  });

  final String title;
  final String destination;
  final double distanceKm;
  final double maxLeanDeg;
  final int curveCount;
  final int riderCount;
  final Duration duration;
  final double? maxSpeedKmh;
  final String hookKind;
  final List<ReelTrailPoint> trail;
  final List<ReelPhoto> photos;

  bool get hasPhotos => photos.isNotEmpty;
}

ReelHighlights buildReelHighlights({
  required RideAnalytics analytics,
  required String title,
  String? destination,
  int riderCount = 1,
  List<ReelPhoto> photos = const [],
  int maxTrailPoints = 180,
}) {
  final samples = analytics.samples;
  final trail = _downsample(samples, maxTrailPoints);
  final lean = analytics.maxLeanAbs ?? 0;
  final usePhotoHook = photos.isNotEmpty && lean < 18;
  return ReelHighlights(
    title: title,
    destination: (destination ?? '').trim().isEmpty
        ? title
        : destination!.trim(),
    distanceKm: analytics.distanceKm,
    maxLeanDeg: lean,
    curveCount: analytics.curveEvents.length,
    riderCount: riderCount,
    duration: analytics.duration,
    maxSpeedKmh: analytics.maxSpeedKmh,
    hookKind: usePhotoHook ? 'photo' : 'lean',
    trail: trail,
    photos: photos.take(3).toList(),
  );
}

List<ReelTrailPoint> _downsample(List<TrackPoint> samples, int maxPoints) {
  if (samples.isEmpty) return const [];
  if (samples.length <= maxPoints) {
    return [
      for (final p in samples)
        ReelTrailPoint(
          lat: p.latitude,
          lng: p.longitude,
          leanAbs: p.absLeanDegrees ?? 0,
          speedKmh: p.speedKmh,
        ),
    ];
  }
  final step = samples.length / maxPoints;
  final out = <ReelTrailPoint>[];
  for (var i = 0; i < maxPoints; i++) {
    final p = samples[(i * step).floor().clamp(0, samples.length - 1)];
    out.add(
      ReelTrailPoint(
        lat: p.latitude,
        lng: p.longitude,
        leanAbs: p.absLeanDegrees ?? 0,
        speedKmh: p.speedKmh,
      ),
    );
  }
  return out;
}

Color leanTrailColor(double leanAbs) {
  if (leanAbs < 8) return RideVizPalette.roadRecta;
  if (leanAbs < 22) return RideVizPalette.leanLeft;
  if (leanAbs < 35) return RideVizPalette.leanRight;
  return RideVizPalette.speedStops[5].$2;
}

Future<ui.Image> decodeUiImage(Uint8List bytes, {int? targetWidth}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: targetWidth,
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
