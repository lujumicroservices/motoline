import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/analytics/corner_skill.dart';
import 'package:motoline/core/analytics/map_curve_engine.dart';
import 'package:motoline/core/analytics/ride_analytics.dart';
import 'package:motoline/core/analytics/road_kind_detection.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/core/models/track_point.dart';
import 'package:motoline/core/services/map_match_service.dart';
import 'package:motoline/core/routing/polyline_codec.dart';
import 'package:motoline/core/utils/geo_utils.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const engine = MapCurveEngine();

  test('90-degree street corner is one right-hand map curve', () {
    final poly = _rightAngle(lat0: 20.72, lng0: -103.42, left: false);
    final curves = engine.detect(centerline: poly, fromMapMatch: true);
    expect(curves, isNotEmpty);
    final c = curves.first;
    expect(c.side, TurnSide.derecha);
    expect(c.headingChangeDeg.abs(), greaterThanOrEqualTo(35));
    expect(c.fromMapMatch, isTrue);
  });

  test('GPS-only fallback still finds the same right-hand bend', () {
    final poly = _rightAngle(lat0: 20.71, lng0: -103.41, left: false);
    final curves = engine.detect(centerline: poly, fromMapMatch: false);
    expect(curves, isNotEmpty);
    expect(curves.first.side, TurnSide.derecha);
    expect(curves.first.fromMapMatch, isFalse);
  });

  test('rider apex after map apex is along-track late', () {
    final poly = _rightAngle(lat0: 20.70, lng0: -103.40, left: false);
    final curves = engine.detect(centerline: poly, fromMapMatch: true);
    expect(curves, isNotEmpty);
    final curve = curves.first;
    final line = curve.poly;

    final t0 = DateTime.utc(2026, 9, 11, 14, 37);
    final samples = <TrackPoint>[];
    for (var i = 0; i < line.length; i++) {
      final p = line[i];
      samples.add(
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: p.lat,
          longitude: p.lng,
          timestamp: t0.add(Duration(milliseconds: i * 400)),
          speedMps: 12,
          leanDegrees: i == line.length - 1 ? 28 : 6,
        ),
      );
    }

    final rider = engine.attachRider(
      curve: curve,
      samples: samples,
      neutralLeanDegrees: 0,
    );
    expect(rider, isNotNull);
    expect(rider!.apexGapAlongM, isNotNull);
    expect(rider.apexGapAlongM!, greaterThan(8));
    expect(rider.timing, 'despues');
    expect(rider.riderLeanDegrees, greaterThan(0));
  });

  test('Tesistán 08:37 — four map corners, no stray nearby-street hits', () {
    final raw = jsonDecode(
      File('test/fixtures/tesistan_08_37_curves.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final items = raw['curves'] as List<dynamic>;
    expect(items, hasLength(4));

    final foundSides = <TurnSide>[];
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final poly = [
        for (final row in map['poly'] as List<dynamic>)
          GeoPoint((row[0] as num).toDouble(), (row[1] as num).toDouble()),
      ];
      final curves = engine.detect(centerline: poly, fromMapMatch: true);
      expect(
        curves,
        isNotEmpty,
        reason: 'expected a curve on ${map['name']}',
      );
      foundSides.add(curves.first.side);

      final wantLeft = map['side'] == 'izquierda';
      expect(curves.first.side == TurnSide.izquierda, wantLeft);

      final gps = <TrackPoint>[];
      final t0 = DateTime.utc(2026, 9, 11, 14, 37);
      final rows = map['gps'] as List<dynamic>;
      for (var i = 0; i < rows.length; i++) {
        final row = rows[i] as List<dynamic>;
        gps.add(
          TrackPoint(
            id: i,
            rideId: 'ivan',
            latitude: (row[0] as num).toDouble(),
            longitude: (row[1] as num).toDouble(),
            timestamp: t0.add(Duration(seconds: i)),
            speedMps: (row[3] as num).toDouble() / 3.6,
            leanDegrees: (row[2] as num).toDouble(),
          ),
        );
      }
      final rider = engine.attachRider(
        curve: curves.first,
        samples: gps,
        neutralLeanDegrees: 0,
      );
      expect(rider, isNotNull, reason: map['name'] as String);
      expect(rider!.entryIndex, lessThan(rider.exitIndex));
    }

    expect(foundSides.where((s) => s == TurnSide.derecha).length, 3);
    expect(foundSides.where((s) => s == TurnSide.izquierda).length, 1);

    final decoy = GeoPoint(20.7274, -103.4148);
    for (final item in items) {
      final map = item as Map<String, dynamic>;
      final poly = [
        for (final row in map['poly'] as List<dynamic>)
          GeoPoint((row[0] as num).toDouble(), (row[1] as num).toDouble()),
      ];
      final apex = engine.detect(centerline: poly, fromMapMatch: true).first.mapApex;
      final onStreet = projectOntoPoly(apex, poly)!.distM;
      final toDecoy = haversineMeters(apex.lat, apex.lng, decoy.lat, decoy.lng);
      expect(onStreet, lessThan(12), reason: map['name'] as String);
      expect(toDecoy, greaterThan(40), reason: 'must not snap to nearby unused street');
    }
  });

  test('center-mount Ivan set is six rides; Santa Catalina is excluded', () {
    final raw = jsonDecode(
      File('test/fixtures/tesistan_08_37_curves.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final rides = (raw['center_mount_rides'] as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['id'] as String)
        .toList();
    expect(rides, hasLength(6));
    expect(rides.toSet(), hasLength(6));
    expect(rides, contains(raw['ride_id']));
    final excluded = (raw['excluded_not_center_mount'] as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['id'] as String);
    for (final id in excluded) {
      expect(rides, isNot(contains(id)));
    }
  });

  test('Skill Lab scores along-track gap; GPS fallback does not claim a street apex', () {
    final poly = _rightAngle(lat0: 20.69, lng0: -103.39, left: false);
    final curves = engine.detect(centerline: poly, fromMapMatch: true);
    expect(curves, isNotEmpty);
    final curve = curves.first;
    final line = curve.poly;
    final t0 = DateTime.utc(2026, 9, 11, 14, 37);
    final samples = <TrackPoint>[
      for (var i = 0; i < line.length; i++)
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: line[i].lat,
          longitude: line[i].lng,
          timestamp: t0.add(Duration(milliseconds: i * 400)),
          speedMps: 12,
          leanDegrees: i == line.length - 1 ? 28 : 6,
        ),
    ];
    final rider = engine.attachRider(
      curve: curve,
      samples: samples,
      neutralLeanDegrees: 0,
    );
    expect(rider, isNotNull);
    final summary = const CornerSkillEngine().evaluateRiders(
      samples: samples,
      riders: [rider!],
    );
    expect(summary.corners, isNotEmpty);
    expect(summary.corners.first.analysis.fromMapMatch, isTrue);
    expect(summary.corners.first.analysis.mapApexLat, isNotNull);
    expect(
      summary.corners.first.tips.any((t) => t.id == SkillTipId.apexLate),
      isTrue,
    );

    final ride = Ride(
      id: 'r',
      startedAt: t0,
      status: RideStatus.completed,
      endedAt: t0.add(Duration(milliseconds: samples.length * 400)),
      pointCount: samples.length,
    );
    final gpsOnly = RideAnalytics(ride: ride, points: samples);
    expect(gpsOnly.mapCurves, isNotEmpty);
    expect(gpsOnly.mapCurves.first.fromMapMatch, isFalse);
    expect(gpsOnly.skillSummary.corners, isNotEmpty);
    expect(gpsOnly.skillSummary.corners.first.analysis.fromMapMatch, isFalse);
    expect(gpsOnly.skillSummary.corners.first.analysis.mapApexLat, isNull);
  });

  test('MapMatchService decodes matched polyline from the edge function', () async {
    const pts = [
      LatLng(20.7269, -103.4140),
      LatLng(20.7267, -103.4161),
      LatLng(20.7276, -103.4157),
    ];
    final encoded = encodePolyline(pts);
    final svc = MapMatchService(
      invoke: (body) async {
        expect(body['shape'], isA<List>());
        return {'polyline': encoded, 'provider': 'valhalla'};
      },
    );
    final samples = [
      for (var i = 0; i < pts.length; i++)
        TrackPoint(
          id: i,
          rideId: 'r',
          latitude: pts[i].latitude,
          longitude: pts[i].longitude,
          timestamp: DateTime.utc(2026, 9, 11).add(Duration(seconds: i)),
          speedMps: 10,
        ),
    ];
    final matched = await svc.match(samples, stepM: 1);
    expect(matched, isNotNull);
    expect(matched!.length, pts.length);
    expect(matched.first.lat, closeTo(pts.first.latitude, 1e-4));
  });
}

List<GeoPoint> _rightAngle({
  required double lat0,
  required double lng0,
  required bool left,
}) {
  const meters = 8.0;
  const degLat = meters / 111320.0;
  final degLng = meters / (111320.0 * 0.94);
  final out = <GeoPoint>[];
  var lat = lat0;
  var lng = lng0;
  for (var i = 0; i < 22; i++) {
    out.add(GeoPoint(lat, lng));
    lat += degLat;
  }
  for (var i = 0; i < 22; i++) {
    out.add(GeoPoint(lat, lng));
    lng += left ? -degLng : degLng;
  }
  return out;
}
