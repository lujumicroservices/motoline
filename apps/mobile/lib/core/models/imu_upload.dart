enum ImuUploadStatus {
  pending,
  uploading,
  uploaded,
  failed;

  String get id => name;

  static ImuUploadStatus fromId(String? id) => switch (id) {
        'uploaded' => ImuUploadStatus.uploaded,
        'uploading' => ImuUploadStatus.uploading,
        'failed' => ImuUploadStatus.failed,
        _ => ImuUploadStatus.pending,
      };
}

class ImuUploadRow {
  const ImuUploadRow({
    required this.rideId,
    required this.status,
    this.blobPath,
    this.error,
    required this.updatedAtMs,
  });

  final String rideId;
  final ImuUploadStatus status;
  final String? blobPath;
  final String? error;
  final int updatedAtMs;

  Map<String, Object?> toMap() => {
        'ride_id': rideId,
        'status': status.id,
        'blob_path': blobPath,
        'error': error,
        'updated_at_ms': updatedAtMs,
      };

  factory ImuUploadRow.fromMap(Map<String, Object?> map) => ImuUploadRow(
        rideId: map['ride_id'] as String,
        status: ImuUploadStatus.fromId(map['status'] as String?),
        blobPath: map['blob_path'] as String?,
        error: map['error'] as String?,
        updatedAtMs: (map['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}
