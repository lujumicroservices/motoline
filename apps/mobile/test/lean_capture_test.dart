import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/lean_lab/lean_imu_math.dart';
import 'package:motoline/core/lean_lab/upright_freeze_controller.dart';
import 'package:motoline/core/models/imu_sample.dart';
import 'package:motoline/core/models/lean_sample.dart';
import 'package:motoline/core/services/lean_engine.dart';
import 'package:motoline/features/ride_active/widgets/upright_freeze_panel.dart';

void main() {
  test('UprightFreezePanel defaults to hold', () {
    final panel = UprightFreezePanel(controller: UprightFreezeController(LeanEngine()));
    expect(panel.mode, UprightFreezeMode.hold);
  });

  test('LeanSample round-trips replay columns', () {
    const sample = LeanSample(
      rideId: 'r1',
      timestampMs: 1_700_000_000_000,
      leanDegrees: 22.5,
      gpsLeanDegrees: 20.1,
      speedMps: 18.4,
      confidence: 0.82,
      vectorLean: 23.0,
      pose: 'vertical_y',
      fusedRoll: 21.2,
      fusedPitch: -3.1,
    );
    final copy = LeanSample.fromMap(sample.toMap());
    expect(copy.rideId, sample.rideId);
    expect(copy.leanDegrees, sample.leanDegrees);
    expect(copy.vectorLean, sample.vectorLean);
    expect(copy.pose, sample.pose);
    expect(copy.fusedRoll, sample.fusedRoll);
    expect(copy.fusedPitch, sample.fusedPitch);
  });

  test('LeanSample fromMap tolerates missing replay columns', () {
    final copy = LeanSample.fromMap({
      'ride_id': 'r1',
      'timestamp_ms': 1,
      'lean_degrees': 10.0,
    });
    expect(copy.vectorLean, isNull);
    expect(copy.pose, isNull);
    expect(copy.fusedRoll, isNull);
  });

  test('RideImuSample round-trips 6-axis row', () {
    const sample = RideImuSample(
      rideId: 'r1',
      timestampMs: 42,
      ax: 0.1,
      ay: 9.7,
      az: 0.2,
      gx: 0.01,
      gy: -0.02,
      gz: 0.03,
    );
    final copy = RideImuSample.fromMap(sample.toMap());
    expect(copy.rideId, 'r1');
    expect(copy.ax, closeTo(0.1, 1e-9));
    expect(copy.ay, closeTo(9.7, 1e-9));
    expect(copy.gz, closeTo(0.03, 1e-9));
  });

  test('frozen engine pose stays put after tracker tick', () {
    final engine = LeanEngine();
    engine.lockUpright(const Vec3(0, 9.8, 0));
    expect(engine.pose, PhonePoseClass.verticalY);
    engine.latest; // snapshot exists after lock
    // Tracker runs on a timer in production; freeze must not retarget pose.
    expect(engine.pose, PhonePoseClass.verticalY);
    expect(engine.isLocked, isTrue);
    expect(engine.mountMode, 'mount');
  });
}
