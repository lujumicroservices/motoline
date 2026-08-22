import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:motoline/core/services/place_search_service.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;
  Uri? lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    final res = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(res.bodyBytes),
      res.statusCode,
      request: request,
      headers: res.headers,
    );
  }
}

void main() {
  test('viewBoundsPayload encodes south west north east', () {
    final bounds = LatLngBounds(
      const LatLng(20.6, -103.4),
      const LatLng(20.7, -103.3),
    );
    final payload = viewBoundsPayload(bounds)!;
    expect(payload['south'], closeTo(20.6, 1e-9));
    expect(payload['west'], closeTo(-103.4, 1e-9));
    expect(payload['north'], closeTo(20.7, 1e-9));
    expect(payload['east'], closeTo(-103.3, 1e-9));
    expect(viewBoundsPayload(null), isNull);
  });

  test('parseGooglePlaceHits skips incomplete rows', () {
    final hits = parseGooglePlaceHits({
      'hits': [
        {
          'title': 'Desayunador Las Bugambilias',
          'subtitle': 'Tapalpa, Jalisco',
          'lat': 20.16,
          'lng': -103.76,
          'primary_type': 'restaurant',
        },
        {'title': 'No coords'},
        {
          'title': 'Guadalajara',
          'lat': 20.67,
          'lng': -103.35,
        },
      ],
    });
    expect(hits, hasLength(2));
    expect(hits.first.title, 'Desayunador Las Bugambilias');
    expect(hits.first.point, const LatLng(20.16, -103.76));
    expect(hits.last.title, 'Guadalajara');
  });

  test('search prefers Google and sends viewport bounds', () async {
    Map<String, dynamic>? sent;
    final svc = PlaceSearchService(
      invoke: (body) async {
        sent = body;
        return {
          'hits': [
            {
              'title': 'Café Palomas',
              'subtitle': 'Guadalajara',
              'lat': 20.68,
              'lng': -103.35,
            },
          ],
          'provider': 'google_places',
        };
      },
      client: _FakeClient((_) async => http.Response('[]', 200)),
    );
    final bounds = LatLngBounds(
      const LatLng(20.6, -103.4),
      const LatLng(20.7, -103.3),
    );
    final hits = await svc.search('cafe', viewBounds: bounds);
    expect(hits, hasLength(1));
    expect(hits.first.title, 'Café Palomas');
    expect(sent?['query'], 'cafe');
    expect(sent?['bounds'], isA<Map>());
    expect((sent!['bounds'] as Map)['south'], closeTo(20.6, 1e-9));
  });

  test('short queries never hit providers', () async {
    var invoked = false;
    final svc = PlaceSearchService(
      invoke: (_) async {
        invoked = true;
        return {'hits': []};
      },
    );
    expect(await svc.search('T'), isEmpty);
    expect(invoked, isFalse);
  });

  test('falls back to Nominatim when Google returns nothing', () async {
    final client = _FakeClient((_) async {
      return http.Response(
        jsonEncode([
          {
            'lat': '20.67',
            'lon': '-103.35',
            'name': 'Guadalajara',
            'display_name': 'Guadalajara, Jalisco, México',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final svc = PlaceSearchService(
      client: client,
      invoke: (_) async => null,
    );
    final hits = await svc.search('Guadalajara');
    expect(hits, hasLength(1));
    expect(hits.first.title, 'Guadalajara');
    expect(client.lastUri?.host, 'nominatim.openstreetmap.org');
  });

  test('Nominatim HTTP error yields no hits after Google miss', () async {
    final bad = PlaceSearchService(
      client: _FakeClient((_) async => http.Response('nope', 500)),
      invoke: (_) async => {'hits': []},
    );
    expect(await bad.search('Tapalpa'), isEmpty);
  });
}
