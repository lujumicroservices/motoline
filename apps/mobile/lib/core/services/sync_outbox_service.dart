import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ride_core/ride_core.dart';
import 'package:uuid/uuid.dart';

import '../db/ride_database.dart';
import 'ride_sync_service.dart';

/// Durable local outbox for ride uploads. Survives offline / app kill.
///
/// Jobs are processed by [drain]: each ride_upload calls [RideSyncService.syncRide].
class SyncOutboxService {
  SyncOutboxService({
    RideDatabase? database,
    RideSyncService? sync,
  })  : _db = database ?? RideDatabase.instance,
        _sync = sync ?? RideSyncService();

  final RideDatabase _db;
  final RideSyncService _sync;
  static const _uuid = Uuid();

  /// Enqueue a completed ride for upload (idempotent per ride while pending).
  Future<void> enqueueRideUpload(String rideLocalId) async {
    if (await _db.hasPendingSyncOutboxForRide(rideLocalId)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = SyncOutboxItem(
      id: _uuid.v4(),
      kind: SyncOutboxKind.rideUpload,
      rideLocalId: rideLocalId,
      payloadJson: jsonEncode({'ride_local_id': rideLocalId}),
      status: SyncOutboxStatus.pending,
      attempts: 0,
      createdAtMs: now,
    );
    await _db.upsertSyncOutboxItem(item.toMap());
    debugPrint('SyncOutbox: enqueued ride_upload $rideLocalId');
  }

  /// Process pending jobs. Returns how many succeeded / failed this pass.
  Future<({int ok, int fail})> drain({int limit = 10}) async {
    var ok = 0;
    var fail = 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await _db.listPendingSyncOutbox(nowMs: now, limit: limit);
    for (final row in rows) {
      final item = SyncOutboxItem.fromMap(row);
      await _db.updateSyncOutboxStatus(
        id: item.id,
        status: SyncOutboxStatus.inFlight.dbValue,
        attempts: item.attempts,
      );

      if (item.kind == SyncOutboxKind.rideUpload) {
        final cloudId = await _sync.syncRide(item.rideLocalId);
        if (cloudId != null) {
          await _db.updateSyncOutboxStatus(
            id: item.id,
            status: SyncOutboxStatus.done.dbValue,
            attempts: item.attempts + 1,
          );
          await _db.deleteDoneSyncOutboxForRide(item.rideLocalId);
          ok++;
        } else {
          final attempts = item.attempts + 1;
          await _db.updateSyncOutboxStatus(
            id: item.id,
            status: SyncOutboxStatus.failed.dbValue,
            attempts: attempts,
            nextAttemptAtMs: SyncOutboxItem.nextAttemptMs(
              attempts: attempts,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            ),
            lastError: _sync.lastSyncError,
          );
          fail++;
        }
      } else {
        // track_chunk reserved; ride_upload already chunks points inside syncRide.
        await _db.updateSyncOutboxStatus(
          id: item.id,
          status: SyncOutboxStatus.done.dbValue,
        );
        ok++;
      }
    }
    return (ok: ok, fail: fail);
  }
}
