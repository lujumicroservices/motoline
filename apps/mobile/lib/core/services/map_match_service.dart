import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/map_curve_engine.dart';
import '../models/track_point.dart';
import '../routing/polyline_codec.dart';
import '../supabase/supabase_bootstrap.dart';

typedef MatchInvoker = Future<Map<String, dynamic>?> Function(
  Map<String, dynamic> body,
);

/// Snaps a recorded GPS trace to the road network via `valhalla-match`.
class MapMatchService {
  MapMatchService({MatchInvoker? invoke}) : _invoke = invoke ?? _defaultInvoke;

  final MatchInvoker _invoke;

  Future<List<GeoPoint>?> match(
    List<TrackPoint> samples, {
    double stepM = 18,
  }) async {
    final shape = decimateTrack(samples, stepM: stepM);
    if (shape.length < 2) return null;
    try {
      final data = await _invoke({
        'shape': [
          for (final p in shape) {'lat': p.lat, 'lon': p.lng},
        ],
      });
      if (data == null) return null;
      final poly = data['polyline'];
      if (poly is! String || poly.isEmpty) return null;
      final pts = decodePolyline(poly);
      if (pts.length < 2) return null;
      return [for (final p in pts) GeoPoint(p.latitude, p.longitude)];
    } catch (e) {
      debugPrint('MapMatchService: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _defaultInvoke(
    Map<String, dynamic> body,
  ) async {
    if (!SupabaseBootstrap.isReady) return null;
    await SupabaseBootstrap.ensureSession();
    final res = await SupabaseBootstrap.client.functions.invoke(
      'valhalla-match',
      body: body,
    );
    if (res.status != 200) {
      debugPrint('valhalla-match ${res.status}: ${res.data}');
      return null;
    }
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

final mapMatchServiceProvider = Provider<MapMatchService>((ref) {
  return MapMatchService();
});
