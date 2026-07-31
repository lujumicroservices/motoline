import 'dart:math' as math;

import '../models/track_point.dart';

/// Axis-aligned geographic bounding box (WGS84).
class GeoBBox {
  const GeoBBox({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  /// ~250 m pad at mid latitudes (degrees).
  static const double defaultPadDeg = 0.0025;

  GeoBBox padded([double padDeg = defaultPadDeg]) => GeoBBox(
        minLat: minLat - padDeg,
        maxLat: maxLat + padDeg,
        minLng: minLng - padDeg,
        maxLng: maxLng + padDeg,
      );

  bool intersects(GeoBBox other) =>
      minLat <= other.maxLat &&
      maxLat >= other.minLat &&
      minLng <= other.maxLng &&
      maxLng >= other.minLng;

  /// True when boxes overlap after expanding both by [padDeg].
  bool overlapsSimilar(GeoBBox other, {double padDeg = defaultPadDeg}) =>
      padded(padDeg).intersects(other.padded(padDeg));

  Map<String, double> toMap() => {
        'min_lat': minLat,
        'max_lat': maxLat,
        'min_lng': minLng,
        'max_lng': maxLng,
      };
}

/// Compute bbox from GPS samples. Returns null when no points.
GeoBBox? bboxFromPoints(Iterable<TrackPoint> points) {
  double? minLat;
  double? maxLat;
  double? minLng;
  double? maxLng;
  for (final p in points) {
    minLat = minLat == null ? p.latitude : math.min(minLat, p.latitude);
    maxLat = maxLat == null ? p.latitude : math.max(maxLat, p.latitude);
    minLng = minLng == null ? p.longitude : math.min(minLng, p.longitude);
    maxLng = maxLng == null ? p.longitude : math.max(maxLng, p.longitude);
  }
  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return null;
  }
  return GeoBBox(
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  );
}

GeoBBox? bboxFromMap(Map<String, dynamic> map) {
  final minLat = (map['min_lat'] as num?)?.toDouble();
  final maxLat = (map['max_lat'] as num?)?.toDouble();
  final minLng = (map['min_lng'] as num?)?.toDouble();
  final maxLng = (map['max_lng'] as num?)?.toDouble();
  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return null;
  }
  return GeoBBox(
    minLat: minLat,
    maxLat: maxLat,
    minLng: minLng,
    maxLng: maxLng,
  );
}
