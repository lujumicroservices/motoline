import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/lean_lab/grade_profile.dart';
import 'package:motoline/core/lean_lab/lean_lab_circuit.dart';
import 'package:motoline/core/models/track_point.dart';

TrackPoint _pt({
  required double lat,
  required double lng,
  required double alt,
  required int i,
}) {
  return TrackPoint(
    id: null,
    rideId: 'r',
    latitude: lat,
    longitude: lng,
    altitude: alt,
    timestamp: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
    speedMps: 15,
  );
}

void main() {
  test('grade profile detects climb', () {
    // ~11 m east steps, climbing 2 m each (~18% grade).
    final pts = [
      for (var i = 0; i < 20; i++)
        _pt(
          lat: 20.60,
          lng: -103.45 + i * 0.0001,
          alt: 1500 + i * 2.0,
          i: i,
        ),
    ];
    final g = buildGradeProfile(pts, windowMeters: 20);
    expect(g.totalClimbMeters, greaterThan(20));
    expect(g.dominantTrend(5, 15), VertTrend.climbing);
    expect(g.averageGradePct(5, 15), greaterThan(5));
  });

  test('Bugambilias contains plaza and start', () {
    expect(
      BugambiliasCircuit.contains(
        BugambiliasCircuit.plazaLat,
        BugambiliasCircuit.plazaLng,
      ),
      isTrue,
    );
    expect(
      BugambiliasCircuit.contains(
        BugambiliasCircuit.startLat,
        BugambiliasCircuit.startLng,
      ),
      isTrue,
    );
    expect(BugambiliasCircuit.contains(21.0, -103.0), isFalse);
  });

  test('inferDirection outbound toward plaza', () {
    final pts = [
      for (var i = 0; i < 30; i++)
        _pt(
          lat: BugambiliasCircuit.startLat +
              (BugambiliasCircuit.plazaLat - BugambiliasCircuit.startLat) *
                  (i / 29),
          lng: BugambiliasCircuit.startLng +
              (BugambiliasCircuit.plazaLng - BugambiliasCircuit.startLng) *
                  (i / 29),
          alt: 1500,
          i: i,
        ),
    ];
    expect(
      BugambiliasCircuit.inferDirection(pts),
      LeanLabDirection.outbound,
    );
  });
}
