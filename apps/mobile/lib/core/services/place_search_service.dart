import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSearchHit {
  const PlaceSearchHit({
    required this.title,
    required this.point,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final LatLng point;
}

/// Forward geocode via OSM Nominatim (same stack as ride titles).
class PlaceSearchService {
  PlaceSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  DateTime? _lastRequestAt;

  static const _userAgent =
      'RiderLab/1.33 (com.motoline.motoline; place search)';

  Future<List<PlaceSearchHit>> search(
    String query, {
    LatLngBounds? viewBounds,
    int limit = 6,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    await _pace();
    try {
      final params = <String, String>{
        'format': 'jsonv2',
        'q': q,
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
      _lastRequestAt = DateTime.now();
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
      debugPrint('PlaceSearchService: $e');
      return const [];
    }
  }

  Future<void> _pace() async {
    final last = _lastRequestAt;
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
}

final placeSearchServiceProvider = Provider<PlaceSearchService>((ref) {
  return PlaceSearchService();
});
