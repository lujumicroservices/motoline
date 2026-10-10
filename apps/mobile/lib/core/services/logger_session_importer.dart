import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import '../models/imu_sample.dart';
import '../models/ride.dart';
import '../models/track_point.dart';
import '../utils/geo_utils.dart';
import 'ride_sync_service.dart';

/// Imports a logger session folder (manifest + gnss/imu NDJSON) into local SQLite.
class LoggerSessionImporter {
  LoggerSessionImporter({
    RideDatabase? database,
    RideSyncService? sync,
  })  : _db = database ?? RideDatabase.instance,
        _sync = sync;

  final RideDatabase _db;
  final RideSyncService? _sync;
  final _uuid = const Uuid();

  /// [sessionDir] must contain `manifest.json` and `gnss.ndjson`.
  Future<Ride> importDirectory(Directory sessionDir, {bool enqueueSync = true}) async {
    final manifestFile = File('${sessionDir.path}/manifest.json');
    final gnssFile = File('${sessionDir.path}/gnss.ndjson');
    final imuFile = File('${sessionDir.path}/imu.ndjson');
    if (!await gnssFile.exists()) {
      throw StateError('gnss.ndjson missing in ${sessionDir.path}');
    }

    Map<String, dynamic> manifest = {};
    if (await manifestFile.exists()) {
      final raw = await manifestFile.readAsString();
      final decoded = jsonDecode(raw.trim().split('\n').first);
      if (decoded is Map<String, dynamic>) manifest = decoded;
    }

    final sessionId = (manifest['session_id'] as String?)?.trim();
    final rideId = (sessionId != null && sessionId.isNotEmpty)
        ? sessionId
        : _uuid.v4();

    final gnssLines = await _readNdjson(gnssFile);
    final startedUs = (manifest['started_us'] as num?)?.toInt() ?? 0;
    final baseMs = DateTime.now().millisecondsSinceEpoch -
        _durationMs(manifest, gnssLines, startedUs);

    final points = <TrackPoint>[];
    double dist = 0;
    double? maxSpd;
    double spdSum = 0;
    int spdN = 0;
    TrackPoint? prev;

    for (final m in gnssLines) {
      final lat = (m['lat'] as num?)?.toDouble();
      final lng = (m['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final tUs = (m['t_us'] as num?)?.toInt() ?? startedUs;
      final offsetMs = startedUs > 0 ? ((tUs - startedUs) / 1000).round() : 0;
      final ts = DateTime.fromMillisecondsSinceEpoch(baseMs + offsetMs);
      final spd = (m['speed_mps'] as num?)?.toDouble();
      if (spd != null && spd > 0) {
        maxSpd = maxSpd == null ? spd : math.max(maxSpd, spd);
        spdSum += spd;
        spdN++;
      }
      final tp = TrackPoint(
        id: null,
        rideId: rideId,
        latitude: lat,
        longitude: lng,
        timestamp: ts,
        altitude: (m['alt'] as num?)?.toDouble(),
        speedMps: spd,
        accuracyMeters: (m['acc_m'] as num?)?.toDouble(),
        heading: (m['heading'] as num?)?.toDouble(),
      );
      if (prev != null) {
        dist += haversineMeters(
          prev.latitude,
          prev.longitude,
          tp.latitude,
          tp.longitude,
        );
      }
      prev = tp;
      points.add(tp);
    }

    if (points.isEmpty) {
      throw StateError('No GNSS points in session');
    }

    final ride = Ride(
      id: rideId,
      startedAt: points.first.timestamp,
      endedAt: points.last.timestamp,
      status: RideStatus.completed,
      distanceMeters: dist,
      pointCount: points.length,
      maxSpeedMps: maxSpd,
      avgSpeedMps: spdN > 0 ? spdSum / spdN : null,
      title: 'Logger ${manifest['device_id'] ?? rideId.substring(0, 8)}',
      leanMountMode: 'mount',
      source: 'm5_logger',
    );

    await _db.upsertRide(ride);
    await _db.replacePointsForRide(rideId, points);

    if (await imuFile.exists()) {
      final imuLines = await _readNdjson(imuFile);
      final samples = <RideImuSample>[];
      for (final m in imuLines) {
        final tUs = (m['t_us'] as num?)?.toInt() ?? startedUs;
        final offsetMs = startedUs > 0 ? ((tUs - startedUs) / 1000).round() : 0;
        samples.add(
          RideImuSample(
            rideId: rideId,
            timestampMs: baseMs + offsetMs,
            ax: (m['ax'] as num?)?.toDouble() ?? 0,
            ay: (m['ay'] as num?)?.toDouble() ?? 0,
            az: (m['az'] as num?)?.toDouble() ?? 0,
            gx: (m['gx'] as num?)?.toDouble() ?? 0,
            gy: (m['gy'] as num?)?.toDouble() ?? 0,
            gz: (m['gz'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
      if (samples.isNotEmpty) {
        await _db.insertImuSamplesBatch(samples);
      }
    }

    if (enqueueSync && _sync != null) {
      try {
        await _sync.syncRide(rideId);
      } catch (e) {
        debugPrint('Logger import sync deferred: $e');
      }
    }

    return ride;
  }

  int _durationMs(
    Map<String, dynamic> manifest,
    List<Map<String, dynamic>> lines,
    int startedUs,
  ) {
    final endedUs = (manifest['ended_us'] as num?)?.toInt() ?? 0;
    if (startedUs > 0 && endedUs > startedUs) {
      return ((endedUs - startedUs) / 1000).round();
    }
    if (lines.length >= 2) {
      final a = (lines.first['t_us'] as num?)?.toInt() ?? 0;
      final b = (lines.last['t_us'] as num?)?.toInt() ?? 0;
      if (b > a) return ((b - a) / 1000).round();
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> _readNdjson(File file) async {
    final text = await file.readAsString();
    final out = <Map<String, dynamic>>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final o = jsonDecode(t);
        if (o is Map<String, dynamic>) out.add(o);
      } catch (_) {}
    }
    return out;
  }
}
