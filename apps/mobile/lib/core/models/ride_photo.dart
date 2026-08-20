class RidePhoto {
  const RidePhoto({
    required this.id,
    required this.rideId,
    required this.createdAt,
    this.rodadaId,
    this.localPath,
    this.storagePath,
    this.takenAt,
    this.latitude,
    this.longitude,
    this.source,
    this.contentHash,
    this.uploaded = false,
  });

  final String id;
  final String rideId;
  final String? rodadaId;
  final String? localPath;
  final String? storagePath;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;
  final String? source;
  final String? contentHash;
  final bool uploaded;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'ride_id': rideId,
        'rodada_id': rodadaId,
        'local_path': localPath,
        'storage_path': storagePath,
        'taken_at_ms': takenAt?.millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'source': source,
        'content_hash': contentHash,
        'uploaded': uploaded ? 1 : 0,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
      };

  factory RidePhoto.fromMap(Map<String, Object?> map) => RidePhoto(
        id: map['id'] as String,
        rideId: map['ride_id'] as String,
        rodadaId: map['rodada_id'] as String?,
        localPath: map['local_path'] as String?,
        storagePath: map['storage_path'] as String?,
        takenAt: map['taken_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['taken_at_ms'] as int),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        source: map['source'] as String?,
        contentHash: map['content_hash'] as String?,
        uploaded: (map['uploaded'] as int? ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          map['created_at_ms'] as int? ?? 0,
        ),
      );

  RidePhoto copyWith({
    String? rodadaId,
    String? localPath,
    String? storagePath,
    bool? uploaded,
  }) =>
      RidePhoto(
        id: id,
        rideId: rideId,
        rodadaId: rodadaId ?? this.rodadaId,
        localPath: localPath ?? this.localPath,
        storagePath: storagePath ?? this.storagePath,
        takenAt: takenAt,
        latitude: latitude,
        longitude: longitude,
        source: source,
        contentHash: contentHash,
        uploaded: uploaded ?? this.uploaded,
        createdAt: createdAt,
      );
}
