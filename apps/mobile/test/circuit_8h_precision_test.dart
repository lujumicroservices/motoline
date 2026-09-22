import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/experimental/circuit_8h/circuit_8h_precision.dart';

void main() {
  test('keeps a 4 m fix and drops anything wider', () {
    expect(decideCircuit8hFix(accuracyMeters: 4).accepted, isTrue);
    expect(decideCircuit8hFix(accuracyMeters: 3.2).accepted, isTrue);
    expect(
      decideCircuit8hFix(accuracyMeters: 4.1).drop,
      Circuit8hFixDrop.accuracy,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: 8).drop,
      Circuit8hFixDrop.accuracy,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: null).drop,
      Circuit8hFixDrop.accuracy,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: 0).drop,
      Circuit8hFixDrop.accuracy,
    );
  });

  test('drops a teleport and keeps a motorcycle hop', () {
    expect(
      decideCircuit8hFix(
        accuracyMeters: 3,
        jumpMeters: 30,
        dtSeconds: 1,
        reportedSpeedMps: 28,
      ).accepted,
      isTrue,
    );
    expect(
      decideCircuit8hFix(
        accuracyMeters: 3,
        jumpMeters: 500,
        dtSeconds: 1,
        reportedSpeedMps: 20,
      ).drop,
      Circuit8hFixDrop.teleport,
    );
  });

  test('drops a hop that disagrees with reported speed', () {
    expect(
      decideCircuit8hFix(
        accuracyMeters: 3,
        jumpMeters: 40,
        dtSeconds: 1,
        reportedSpeedMps: 2,
      ).drop,
      Circuit8hFixDrop.speed,
    );
  });

  test('a long gap is a recovery, not a teleport', () {
    expect(
      decideCircuit8hFix(
        accuracyMeters: 4,
        jumpMeters: 2000,
        dtSeconds: 20,
      ).accepted,
      isTrue,
    );
  });

  test('marker median needs three tight fixes in one spot', () {
    Circuit8hSurveySample sample(double dLat, double acc) {
      return Circuit8hSurveySample(
        lat: 20.67 + dLat,
        lng: -103.35,
        accuracyM: acc,
        tsMs: 10,
      );
    }

    final fix = medianMarkerFix([
      sample(0, 3.5),
      sample(0.00001, 2.5),
      sample(-0.00001, 3.0),
    ]);
    expect(fix, isNotNull);
    expect(fix!.accuracyM, 3.0);
    expect(fix.lat, closeTo(20.67, 0.00002));

    expect(
      medianMarkerFix([
        sample(0, 3),
        sample(0.001, 3),
        sample(-0.001, 3),
      ]),
      isNull,
    );
    expect(
      medianMarkerFix([
        sample(0, 3),
        sample(0, 3),
      ]),
      isNull,
    );

    final afterStop = medianMarkerFix([
      const Circuit8hSurveySample(
        lat: 20.68,
        lng: -103.35,
        accuracyM: 3,
        tsMs: 1,
      ),
      const Circuit8hSurveySample(
        lat: 20.67,
        lng: -103.35,
        accuracyM: 3,
        tsMs: 5000,
      ),
      const Circuit8hSurveySample(
        lat: 20.67001,
        lng: -103.35,
        accuracyM: 2,
        tsMs: 5300,
      ),
      const Circuit8hSurveySample(
        lat: 20.66999,
        lng: -103.35,
        accuracyM: 3.2,
        tsMs: 5600,
      ),
    ]);
    expect(afterStop, isNotNull);
    expect(afterStop!.lat, closeTo(20.67, 0.00005));
  });
}
