import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../routing/polyline_codec.dart';
import '../routing/route_prefs.dart';
import '../supabase/supabase_bootstrap.dart';

class DirectionsResult {
  const DirectionsResult({
    required this.points,
    required this.encodedPolyline,
    required this.distanceM,
    required this.durationS,
    this.provider = 'valhalla',
  });

  final List<LatLng> points;
  final String encodedPolyline;
  final double distanceM;
  final double durationS;
  final String provider;

  bool get isUsable => points.length >= 2;
}

typedef RouteInvoker = Future<Map<String, dynamic>?> Function(
  Map<String, dynamic> body,
);

/// Road-network route via the `valhalla-route` Edge Function.
class DirectionsService {
  DirectionsService({RouteInvoker? invoke}) : _invoke = invoke ?? _defaultInvoke;

  final RouteInvoker _invoke;

  Future<DirectionsResult?> route({
    required List<LatLng> waypoints,
    RoutePrefs prefs = RoutePrefs.defaults,
  }) async {
    if (waypoints.length < 2) return null;
    try {
      final data = await _invoke({
        'waypoints': [
          for (final p in waypoints)
            {'lat': p.latitude, 'lon': p.longitude},
        ],
        'prefs': prefs.toMap(),
      });
      if (data == null) return null;
      final shapesRaw = data['shapes'];
      final shapes = <String>[];
      if (shapesRaw is List) {
        for (final s in shapesRaw) {
          if (s is String && s.isNotEmpty) shapes.add(s);
        }
      }
      final single = data['polyline'];
      if (shapes.isEmpty && single is String && single.isNotEmpty) {
        shapes.add(single);
      }
      final points = mergeEncodedShapes(shapes);
      if (points.length < 2) return null;
      return DirectionsResult(
        points: points,
        encodedPolyline: encodePolyline(points),
        distanceM: (data['distance_m'] as num?)?.toDouble() ?? 0,
        durationS: (data['duration_s'] as num?)?.toDouble() ?? 0,
        provider: data['provider'] as String? ?? 'valhalla',
      );
    } catch (e) {
      debugPrint('DirectionsService: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _defaultInvoke(
    Map<String, dynamic> body,
  ) async {
    if (!SupabaseBootstrap.isReady) return null;
    await SupabaseBootstrap.ensureSession();
    final res = await SupabaseBootstrap.client.functions.invoke(
      'valhalla-route',
      body: body,
    );
    if (res.status != 200) {
      debugPrint('valhalla-route ${res.status}: ${res.data}');
      return null;
    }
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

final directionsServiceProvider = Provider<DirectionsService>((ref) {
  return DirectionsService();
});

String formatRouteDistance(double meters) {
  final km = meters / 1000;
  if (km <= 0) return '0 km';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}

String formatRouteEta(double seconds) {
  final m = (seconds / 60).round().clamp(0, 24 * 60);
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final rem = m % 60;
  if (rem == 0) return '$h h';
  return '$h h $rem min';
}
