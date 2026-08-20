import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/imu_sample.dart';
import '../models/lean_sample.dart';
import '../models/ride.dart';

final _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool isUuid(String value) => _uuidRe.hasMatch(value);

/// Server and client agree: `{userId}/{rideId}.sqlite.gz` inside `lean-replay`.
String imuReplayBlobName({required String userId, required String rideId}) {
  if (!isUuid(userId) || !isUuid(rideId)) {
    throw ArgumentError('userId and rideId must be UUIDs');
  }
  return '$userId/$rideId.sqlite.gz';
}

String imuReplayBlobPath({required String userId, required String rideId}) =>
    'lean-replay/${imuReplayBlobName(userId: userId, rideId: rideId)}';

Map<String, Object?> imuReplayMetaJson({
  required Ride ride,
  required String userId,
  int imuCount = 0,
  int leanCount = 0,
}) {
  return {
    'schema': 'lean_replay.v1',
    'ride_id': ride.id,
    'user_id': userId,
    'started_at': ride.startedAt.toUtc().toIso8601String(),
    'ended_at': ride.endedAt?.toUtc().toIso8601String(),
    'g0': {
      'x': ride.leanG0X,
      'y': ride.leanG0Y,
      'z': ride.leanG0Z,
    },
    'pose': ride.leanPoseClass,
    'sign_flip': ride.leanSignFlip,
    'freeze_at_ms': ride.leanFreezeAtMs,
    'upright_locked': ride.leanUprightLocked,
    'mount_mode': ride.leanMountMode,
    'imu_count': imuCount,
    'lean10_count': leanCount,
  };
}

String imuSamplesToCsv(List<RideImuSample> samples) {
  final buf = StringBuffer('t_ms,ax,ay,az,gx,gy,gz\n');
  for (final s in samples) {
    buf.writeln(
      '${s.timestampMs},${s.ax},${s.ay},${s.az},${s.gx},${s.gy},${s.gz}',
    );
  }
  return buf.toString();
}

String leanSamplesToCsv(List<LeanSample> samples) {
  final buf = StringBuffer(
    't_ms,lean_degrees,gps_lean_degrees,speed_mps,confidence,'
    'vector_lean,pose,fused_roll,fused_pitch\n',
  );
  for (final s in samples) {
    buf.writeln(
      '${s.timestampMs},${s.leanDegrees},'
      '${s.gpsLeanDegrees ?? ''},${s.speedMps ?? ''},${s.confidence ?? ''},'
      '${s.vectorLean ?? ''},${s.pose ?? ''},'
      '${s.fusedRoll ?? ''},${s.fusedPitch ?? ''}',
    );
  }
  return buf.toString();
}

/// gzip(tar(meta.json, imu.csv, lean10.csv)) — blob still named `.sqlite.gz`.
Uint8List packImuReplayArchive({
  required Ride ride,
  required String userId,
  required List<RideImuSample> imu,
  required List<LeanSample> lean,
}) {
  final meta = utf8.encode(
    jsonEncode(
      imuReplayMetaJson(
        ride: ride,
        userId: userId,
        imuCount: imu.length,
        leanCount: lean.length,
      ),
    ),
  );
  final imuCsv = utf8.encode(imuSamplesToCsv(imu));
  final leanCsv = utf8.encode(leanSamplesToCsv(lean));
  final tar = Archive()
    ..addFile(ArchiveFile('meta.json', meta.length, meta))
    ..addFile(ArchiveFile('imu.csv', imuCsv.length, imuCsv))
    ..addFile(ArchiveFile('lean10.csv', leanCsv.length, leanCsv));
  final tarBytes = TarEncoder().encode(tar);
  final gz = GZipEncoder().encode(tarBytes, level: 6);
  if (gz == null) {
    throw StateError('gzip encode failed');
  }
  return Uint8List.fromList(gz);
}
