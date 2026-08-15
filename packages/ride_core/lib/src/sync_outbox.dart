/// Durable sync outbox job kinds.
enum SyncOutboxKind {
  rideUpload('ride_upload'),
  trackChunk('track_chunk');

  const SyncOutboxKind(this.dbValue);
  final String dbValue;

  static SyncOutboxKind fromDb(String value) {
    return SyncOutboxKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => SyncOutboxKind.rideUpload,
    );
  }
}

enum SyncOutboxStatus {
  pending('pending'),
  inFlight('in_flight'),
  done('done'),
  failed('failed');

  const SyncOutboxStatus(this.dbValue);
  final String dbValue;

  static SyncOutboxStatus fromDb(String value) {
    return SyncOutboxStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => SyncOutboxStatus.pending,
    );
  }
}

/// One durable sync unit — ride upsert or a track-point chunk.
class SyncOutboxItem {
  const SyncOutboxItem({
    required this.id,
    required this.kind,
    required this.rideLocalId,
    required this.payloadJson,
    required this.status,
    required this.attempts,
    required this.createdAtMs,
    this.nextAttemptAtMs,
    this.lastError,
    this.chunkIndex,
  });

  final String id;
  final SyncOutboxKind kind;
  final String rideLocalId;
  final String payloadJson;
  final SyncOutboxStatus status;
  final int attempts;
  final int createdAtMs;
  final int? nextAttemptAtMs;
  final String? lastError;
  final int? chunkIndex;

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.dbValue,
        'ride_local_id': rideLocalId,
        'payload_json': payloadJson,
        'status': status.dbValue,
        'attempts': attempts,
        'created_at_ms': createdAtMs,
        'next_attempt_at_ms': nextAttemptAtMs,
        'last_error': lastError,
        'chunk_index': chunkIndex,
      };

  factory SyncOutboxItem.fromMap(Map<String, dynamic> map) {
    return SyncOutboxItem(
      id: map['id']! as String,
      kind: SyncOutboxKind.fromDb(map['kind']! as String),
      rideLocalId: map['ride_local_id']! as String,
      payloadJson: map['payload_json']! as String,
      status: SyncOutboxStatus.fromDb(map['status']! as String),
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      createdAtMs: (map['created_at_ms'] as num).toInt(),
      nextAttemptAtMs: (map['next_attempt_at_ms'] as num?)?.toInt(),
      lastError: map['last_error'] as String?,
      chunkIndex: (map['chunk_index'] as num?)?.toInt(),
    );
  }

  /// Exponential backoff: 30s, 60s, 120s… capped at 30 min.
  static int nextAttemptMs({
    required int attempts,
    required int nowMs,
  }) {
    final seconds = (30 * (1 << attempts.clamp(0, 6))).clamp(30, 1800);
    return nowMs + seconds * 1000;
  }
}
