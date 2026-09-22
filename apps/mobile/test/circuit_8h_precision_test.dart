import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/experimental/circuit_8h/circuit_8h_precision.dart';

void main() {
  test('keeps an open-sky fix and drops anything wider than 8 m', () {
    expect(
      decideCircuit8hFix(accuracyMeters: 8).accepted,
      isTrue,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: 3.2).accepted,
      isTrue,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: 8.1).drop,
      Circuit8hFixDrop.accuracy,
    );
    expect(
      decideCircuit8hFix(accuracyMeters: 40).drop,
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
        accuracyMeters: 4,
        jumpMeters: 30,
        dtSeconds: 1,
      ).accepted,
      isTrue,
    );
    expect(
      decideCircuit8hFix(
        accuracyMeters: 4,
        jumpMeters: 500,
        dtSeconds: 1,
      ).drop,
      Circuit8hFixDrop.teleport,
    );
  });

  test('a long gap is a recovery, not a teleport', () {
    expect(
      decideCircuit8hFix(
        accuracyMeters: 5,
        jumpMeters: 400,
        dtSeconds: 20,
      ).accepted,
      isTrue,
    );
  });
}
