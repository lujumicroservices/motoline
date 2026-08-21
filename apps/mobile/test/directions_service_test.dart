import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:motoline/core/routing/polyline_codec.dart';
import 'package:motoline/core/routing/route_prefs.dart';
import 'package:motoline/core/services/directions_service.dart';

void main() {
  test('encode/decode polyline6 round-trips', () {
    const pts = [
      LatLng(20.6736, -103.344),
      LatLng(20.6910, -103.399),
      LatLng(20.7201, -103.391),
    ];
    final encoded = encodePolyline(pts);
    expect(encoded, isNotEmpty);
    final decoded = decodePolyline(encoded);
    expect(decoded.length, pts.length);
    for (var i = 0; i < pts.length; i++) {
      expect(decoded[i].latitude, closeTo(pts[i].latitude, 1e-5));
      expect(decoded[i].longitude, closeTo(pts[i].longitude, 1e-5));
    }
  });

  test('mergeEncodedShapes skips shared vertices', () {
    const a = [LatLng(20, -103), LatLng(20.1, -103.1)];
    const b = [LatLng(20.1, -103.1), LatLng(20.2, -103.2)];
    final merged = mergeEncodedShapes([
      encodePolyline(a),
      encodePolyline(b),
    ]);
    expect(merged.length, 3);
    expect(merged.first.latitude, closeTo(20, 1e-5));
    expect(merged.last.latitude, closeTo(20.2, 1e-5));
  });

  test('avoid tolls + streets maps to Valhalla motorcycle costing', () {
    const prefs = RoutePrefs(
      avoidTolls: true,
      allowHighway: false,
      allowStreet: true,
      allowOffroad: false,
    );
    final c = prefs.toValhallaMotorcycle();
    expect(c['use_tolls'], 0.0);
    expect(c['use_highways'], 0.1);
    expect(c['exclude_unpaved'], isTrue);
    expect(c['use_tracks'], 0.0);
  });

  test('off-road chip opens tracks and unpaved', () {
    const prefs = RoutePrefs(
      allowHighway: true,
      allowStreet: true,
      allowOffroad: true,
    );
    final c = prefs.toValhallaMotorcycle();
    expect(c['use_tracks'], 0.8);
    expect(c['use_trails'], 0.6);
    expect(c['exclude_unpaved'], isFalse);
  });

  test('all road chips off yields engine defaults', () {
    const prefs = RoutePrefs(
      allowHighway: false,
      allowStreet: false,
      allowOffroad: false,
    );
    expect(prefs.toValhallaMotorcycle(), isEmpty);
  });

  test('RoutePrefs round-trips through json map', () {
    const prefs = RoutePrefs(
      avoidTolls: true,
      allowHighway: false,
      allowOffroad: true,
    );
    expect(RoutePrefs.fromMap(prefs.toMap()), prefs);
  });

  test('DirectionsService concatenates shapes and falls back on empty', () async {
    final ok = DirectionsService(
      invoke: (_) async => {
        'shapes': [
          encodePolyline(const [LatLng(20, -103), LatLng(20.1, -103)]),
        ],
        'distance_m': 12345.0,
        'duration_s': 900.0,
        'provider': 'valhalla',
      },
    );
    final result = await ok.route(
      waypoints: const [LatLng(20, -103), LatLng(20.1, -103)],
    );
    expect(result, isNotNull);
    expect(result!.points.length, 2);
    expect(result.distanceM, 12345);
    expect(result.durationS, 900);
    expect(decodePolyline(result.encodedPolyline).length, 2);

    final fail = DirectionsService(invoke: (_) async => null);
    expect(
      await fail.route(
        waypoints: const [LatLng(20, -103), LatLng(21, -104)],
      ),
      isNull,
    );
    expect(
      await fail.route(waypoints: const [LatLng(20, -103)]),
      isNull,
    );
  });

  test('format helpers', () {
    expect(formatRouteDistance(1500), '1.5 km');
    expect(formatRouteDistance(42000), '42 km');
    expect(formatRouteEta(90), '2 min');
    expect(formatRouteEta(3600), '1 h');
    expect(formatRouteEta(5400), '1 h 30 min');
  });
}
