import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/track_point.dart';

/// Reverse-geocode start/end of a ride into a short title like
/// `Cañadas - Moyahua` via OpenStreetMap Nominatim (same map stack as the app).
class RidePlaceNameService {
  RidePlaceNameService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _cache = {};
  DateTime? _lastRequestAt;

  static const _userAgent = 'RiderLab/1.27 (com.rawthrottle.riderlab; ride titles)';

  /// Build `Origin - Destination` (e.g. Tesistán - Zapopan).
  Future<String?> titleFromTrack(List<TrackPoint> points) async {
    if (points.isEmpty) return null;
    final start = points.first;
    final end = points.last;
    final a = await _placeLabel(start.latitude, start.longitude);
    // Soft rate-limit before second request.
    await _pace();
    final b = await _placeLabel(end.latitude, end.longitude);
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    if (_samePlace(a, b)) return a;
    return '$a - $b';
  }

  bool _samePlace(String a, String b) {
    final na = a.toLowerCase().trim();
    final nb = b.toLowerCase().trim();
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  Future<String?> _placeLabel(double lat, double lng) async {
    final key =
        '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}'; // ~100 m cache
    final cached = _cache[key];
    if (cached != null) return cached;

    await _pace();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': lat.toString(),
        'lon': lng.toString(),
        // ~town / barrio — better for Tesistán, Cañadas, Zapopan.
        'zoom': '15',
        'addressdetails': '1',
      });
      final res = await _client.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'es,en',
        },
      );
      _lastRequestAt = DateTime.now();
      if (res.statusCode != 200) {
        debugPrint('Nominatim ${res.statusCode}');
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      final label = _pickLabel(Map<String, dynamic>.from(body));
      if (label != null && label.isNotEmpty) {
        _cache[key] = label;
      }
      return label;
    } catch (e) {
      debugPrint('RidePlaceNameService: $e');
      return null;
    }
  }

  Future<void> _pace() async {
    final last = _lastRequestAt;
    if (last == null) return;
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(last);
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
  }

  /// Prefer village / town names common on Mexican mountain roads.
  String? _pickLabel(Map<String, dynamic> body) {
    final address = body['address'];
    if (address is Map) {
      final map = Map<String, dynamic>.from(address);
      const keys = [
        'village',
        'hamlet',
        'suburb',
        'neighbourhood',
        'town',
        'city_district',
        'municipality',
        'city',
        'county',
        'state_district',
      ];
      for (final k in keys) {
        final v = map[k]?.toString().trim();
        if (v != null && v.isNotEmpty) return _shorten(v);
      }
    }
    final display = body['name']?.toString().trim();
    if (display != null && display.isNotEmpty) return _shorten(display);
    final full = body['display_name']?.toString();
    if (full == null || full.isEmpty) return null;
    return _shorten(full.split(',').first.trim());
  }

  String _shorten(String raw) {
    var s = raw.trim();
    // Drop verbose prefixes.
    for (final p in ['Municipio de ', 'Municipio ', 'Localidad ']) {
      if (s.toLowerCase().startsWith(p.toLowerCase())) {
        s = s.substring(p.length).trim();
      }
    }
    if (s.length > 32) s = '${s.substring(0, 30).trim()}…';
    return s;
  }
}
