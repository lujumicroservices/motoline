import 'dart:async';
import 'dart:convert';

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
  test('search parses nominatim hits and ignores short queries', () async {
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
    final svc = PlaceSearchService(client: client);
    expect(await svc.search('T'), isEmpty);

    final hits = await svc.search('Guadalajara');
    expect(hits, hasLength(1));
    expect(hits.first.title, 'Guadalajara');
    expect(hits.first.point, const LatLng(20.67, -103.35));
    expect(hits.first.subtitle, contains('Jalisco'));
    expect(client.lastUri?.host, 'nominatim.openstreetmap.org');
    expect(client.lastUri?.queryParameters['q'], 'Guadalajara');
  });

  test('empty body or HTTP error yields no hits', () async {
    final bad = PlaceSearchService(
      client: _FakeClient((_) async => http.Response('nope', 500)),
    );
    expect(await bad.search('Tapalpa'), isEmpty);
  });
}
