import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/models/imu_sample.dart';
import 'package:motoline/core/models/lean_sample.dart';
import 'package:motoline/core/models/ride.dart';
import 'package:motoline/core/services/imu_replay_packager.dart';

void main() {
  test('blob path is user/ride.sqlite.gz under lean-replay', () {
    const user = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    const ride = '11111111-2222-4333-8444-555555555555';
    expect(
      imuReplayBlobName(userId: user, rideId: ride),
      '$user/$ride.sqlite.gz',
    );
    expect(
      imuReplayBlobPath(userId: user, rideId: ride),
      'lean-replay/$user/$ride.sqlite.gz',
    );
  });

  test('rejects non-uuid path pieces', () {
    expect(
      () => imuReplayBlobName(userId: 'nope', rideId: '11111111-2222-4333-8444-555555555555'),
      throwsArgumentError,
    );
  });

  test('packager gzip contains meta, imu csv, lean10 csv', () {
    final ride = Ride(
      id: '11111111-2222-4333-8444-555555555555',
      startedAt: DateTime.utc(2026, 8, 20, 3),
      status: RideStatus.completed,
      endedAt: DateTime.utc(2026, 8, 20, 4),
      leanUprightLocked: true,
      leanG0X: 0.1,
      leanG0Y: 9.7,
      leanG0Z: 0.2,
      leanPoseClass: 'verticalY',
    );
    const user = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    final bytes = packImuReplayArchive(
      ride: ride,
      userId: user,
      imu: const [
        RideImuSample(
          rideId: '11111111-2222-4333-8444-555555555555',
          timestampMs: 1,
          ax: 0.1,
          ay: 9.8,
          az: 0,
          gx: 0.01,
          gy: 0,
          gz: -0.02,
        ),
      ],
      lean: const [
        LeanSample(
          rideId: '11111111-2222-4333-8444-555555555555',
          timestampMs: 1,
          leanDegrees: 12.5,
          pose: 'vertical_y',
        ),
      ],
    );
    expect(bytes.length, greaterThan(40));
    expect(bytes[0], 0x1f);
    expect(bytes[1], 0x8b);
    expect(imuSamplesToCsv(const [
      RideImuSample(
        rideId: 'r',
        timestampMs: 9,
        ax: 1,
        ay: 2,
        az: 3,
        gx: 4,
        gy: 5,
        gz: 6,
      ),
    ]), contains('9,1.0,2.0,3.0,4.0,5.0,6.0'));
  });
}
