import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../db/ride_database.dart';
import '../models/imu_upload.dart';
import '../models/ride.dart';
import '../supabase/supabase_bootstrap.dart';
import 'imu_replay_packager.dart';

/// Packs local IMU + lean10 and PUTs to Azure Blob using a Function-minted SAS.
class ImuBlobUploadService {
  ImuBlobUploadService({RideDatabase? database})
      : _db = database ?? RideDatabase.instance;

  final RideDatabase _db;

  static String? get sasUrl {
    final raw = dotenv.env['AZURE_LEAN_SAS_URL']?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  static bool get isConfigured => sasUrl != null;

  Future<ImuUploadRow?> statusFor(String rideId) => _db.getImuUpload(rideId);

  /// Queue + run in the background after ride stop.
  Future<void> enqueueAndUpload(String rideId) async {
    if (!isConfigured) return;
    await _db.upsertImuUpload(
      ImuUploadRow(
        rideId: rideId,
        status: ImuUploadStatus.pending,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await uploadRide(rideId);
  }

  Future<bool> uploadRide(String rideId) async {
    final endpoint = sasUrl;
    if (endpoint == null) return false;

    final ride = await _db.getRide(rideId);
    if (ride == null || ride.status != RideStatus.completed) return false;

    await _db.upsertImuUpload(
      ImuUploadRow(
        rideId: rideId,
        status: ImuUploadStatus.uploading,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    try {
      if (!SupabaseBootstrap.isReady) {
        throw StateError('Supabase not ready');
      }
      final session = await SupabaseBootstrap.ensureSession();
      final token = session?.accessToken;
      final userId = session?.user.id;
      if (token == null || userId == null) {
        throw StateError('Not signed in');
      }

      final imu = await _db.getImuSamples(rideId);
      final lean = await _db.getLeanSamples(rideId);
      final bytes = packImuReplayArchive(
        ride: ride,
        userId: userId,
        imu: imu,
        lean: lean,
      );

      final sasRes = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ride_id': rideId}),
      );
      if (sasRes.statusCode != 200) {
        throw StateError('SAS ${sasRes.statusCode}: ${sasRes.body}');
      }
      final decoded = jsonDecode(sasRes.body) as Map<String, dynamic>;
      final uploadUrl = decoded['uploadUrl'] as String?;
      final blobPath = decoded['blobPath'] as String?;
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw StateError('SAS response missing uploadUrl');
      }

      final put = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'x-ms-blob-type': 'BlockBlob',
          'Content-Type': 'application/gzip',
          'Content-Length': '${bytes.length}',
        },
        body: bytes,
      );
      if (put.statusCode < 200 || put.statusCode >= 300) {
        throw StateError('Blob PUT ${put.statusCode}: ${put.body}');
      }

      await _db.upsertImuUpload(
        ImuUploadRow(
          rideId: rideId,
          status: ImuUploadStatus.uploaded,
          blobPath: blobPath,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return true;
    } catch (e, st) {
      debugPrint('IMU blob upload: $e\n$st');
      await _db.upsertImuUpload(
        ImuUploadRow(
          rideId: rideId,
          status: ImuUploadStatus.failed,
          error: e.toString(),
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return false;
    }
  }
}
