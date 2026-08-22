import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../supabase/supabase_bootstrap.dart';

class PlaceSearchHit {
  const PlaceSearchHit({
    required this.title,
    required this.point,
    this.subtitle,
    this.primaryType,
  });

  final String title;
  final String? subtitle;
  final LatLng point;
  final String? primaryType;
}

typedef PlaceSearchInvoker = Future<Map<String, dynamic>?> Function(
  Map<String, dynamic> body,
);

Map<String, double>? viewBoundsPayload(LatLngBounds? bounds) {
  if (bounds == null) return null;
  return {
    'south': bounds.south,
    'west': bounds.west,
    'north': bounds.north,
    'east': bounds.east,
  };
}

List<PlaceSearchHit> parseGooglePlaceHits(Map<String, dynamic> data) {
  final raw = data['hits'];
  if (raw is! List) return const [];
  final out = <PlaceSearchHit>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final map = Map<String, dynamic>.from(row);
    final lat = (map['lat'] as num?)?.toDouble();
    final lng = (map['lng'] as num?)?.toDouble();
    final title = map['title']?.toString().trim() ?? '';
    if (lat == null || lng == null || title.isEmpty) continue;
    final subtitle = map['subtitle']?.toString().trim();
    out.add(
      PlaceSearchHit(
        title: title,
        subtitle: (subtitle == null || subtitle.isEmpty) ? null : subtitle,
        point: LatLng(lat, lng),
        primaryType: map['primary_type']?.toString(),
      ),
    );
  }
  return out;
}

/// Google Places via `places-search`, Nominatim fallback.
class PlaceSearchService {
  PlaceSearchService({
    http.Client? client,
    PlaceSearchInvoker? invoke,
  })  : _client = client ?? http.Client(),
        _invoke = invoke ?? _defaultInvoke;

  final http.Client _client;
  final PlaceSearchInvoker _invoke;
  DateTime? _lastNominatimAt;

  static const _userAgent =
      'RiderLab/1.35 (com.rawthrottle.riderlab; place search)';

  Future<List<PlaceSearchHit>> search(
    String query, {
    LatLngBounds? viewBounds,
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final google = await _searchGoogle(
        q,
        viewBounds: viewBounds,
        limit: limit,
      );
      if (google.isNotEmpty) return google;
    } catch (e) {
      debugPrint('PlaceSearchService google: $e');
    }
    return _searchNominatim(q, viewBounds: viewBounds, limit: limit);
  }

  Future<List<PlaceSearchHit>> _searchGoogle(
    String query, {
    LatLngBounds? viewBounds,
    int limit = 10,
  }) async {
    final data = await _invoke({
      'query': query,
      'limit': limit,
      if (viewBoundsPayload(viewBounds) != null)
        'bounds': viewBoundsPayload(viewBounds),
    });
    if (data == null) return const [];
    return parseGooglePlaceHits(data);
  }

  Future<List<PlaceSearchHit>> _searchNominatim(
    String query, {
    LatLngBounds? viewBounds,
    int limit = 10,
  }) async {
    await _paceNominatim();
    try {
      final params = <String, String>{
        'format': 'jsonv2',
        'q': query,
        'limit': '$limit',
        'addressdetails': '1',
      };
      if (viewBounds != null) {
        params['viewbox'] =
            '${viewBounds.west},${viewBounds.south},${viewBounds.east},${viewBounds.north}';
        params['bounded'] = '0';
      }
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
      final res = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'es,en',
        },
      );
      _lastNominatimAt = DateTime.now();
      if (res.statusCode != 200) {
        debugPrint('Nominatim search ${res.statusCode}');
        return const [];
      }
      final body = jsonDecode(res.body);
      if (body is! List) return const [];
      final out = <PlaceSearchHit>[];
      for (final row in body) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        final lat = double.tryParse('${map['lat']}');
        final lon = double.tryParse('${map['lon']}');
        if (lat == null || lon == null) continue;
        final title = _title(map);
        if (title.isEmpty) continue;
        out.add(
          PlaceSearchHit(
            title: title,
            subtitle: _subtitle(map, title),
            point: LatLng(lat, lon),
          ),
        );
      }
      return out;
    } catch (e) {
      debugPrint('PlaceSearchService nominatim: $e');
      return const [];
    }
  }

  Future<void> _paceNominatim() async {
    final last = _lastNominatimAt;
    if (last == null) return;
    final wait =
        const Duration(milliseconds: 1100) - DateTime.now().difference(last);
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
  }

  String _title(Map<String, dynamic> map) {
    final named = map['name']?.toString().trim();
    if (named != null && named.isNotEmpty) return named;
    final display = map['display_name']?.toString() ?? '';
    if (display.isEmpty) return '';
    return display.split(',').first.trim();
  }

  String? _subtitle(Map<String, dynamic> map, String title) {
    final display = map['display_name']?.toString();
    if (display == null || display.isEmpty) return null;
    final rest = display.split(',').skip(1).map((s) => s.trim()).where(
          (s) => s.isNotEmpty && s.toLowerCase() != title.toLowerCase(),
        );
    final joined = rest.take(3).join(', ');
    return joined.isEmpty ? null : joined;
  }

  static Future<Map<String, dynamic>?> _defaultInvoke(
    Map<String, dynamic> body,
  ) async {
    if (!SupabaseBootstrap.isReady) return null;
    await SupabaseBootstrap.ensureSession();
    final res = await SupabaseBootstrap.client.functions.invoke(
      'places-search',
      body: body,
    );
    if (res.status != 200) {
      debugPrint('places-search ${res.status}: ${res.data}');
      return null;
    }
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  return PlaceSearchService();
});
