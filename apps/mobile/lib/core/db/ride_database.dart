import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/imu_sample.dart';
import '../models/imu_upload.dart';
import '../models/lean_sample.dart';
import '../models/ride.dart';
import '../models/ride_photo.dart';
import '../models/route_circuit.dart';
import '../models/route_loop.dart';
import '../models/track_point.dart';

class RideDatabase {
  RideDatabase._();
  static final RideDatabase instance = RideDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'motoline.db');
    return openDatabase(
      path,
      version: 20,
      onConfigure: (db) async {
        // Outdoor-grade durability: survive kills mid-batch flush.
        // Android requires rawQuery for PRAGMAs that return a row
        // (execute → SQLITE "query/rawQuery methods only").
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE rides (
            id TEXT PRIMARY KEY,
            started_at_ms INTEGER NOT NULL,
            ended_at_ms INTEGER,
            status TEXT NOT NULL,
            distance_meters REAL NOT NULL DEFAULT 0,
            point_count INTEGER NOT NULL DEFAULT 0,
            max_speed_mps REAL,
            avg_speed_mps REAL,
            max_lean_degrees REAL,
            route_id TEXT,
            is_shared INTEGER NOT NULL DEFAULT 0,
            visibility TEXT NOT NULL DEFAULT 'friends',
            title TEXT,
            lean_upright_locked INTEGER NOT NULL DEFAULT 0,
            lean_g0_x REAL,
            lean_g0_y REAL,
            lean_g0_z REAL,
            lean_pose_class TEXT,
            lean_sign_flip INTEGER NOT NULL DEFAULT 1,
            lean_freeze_at_ms INTEGER,
            lean_mount_mode TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE track_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ride_id TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL,
            speed_mps REAL,
            accuracy_meters REAL,
            heading REAL,
            lean_degrees REAL,
            pressure_hpa REAL,
            timestamp_ms INTEGER NOT NULL,
            FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_points_ride ON track_points(ride_id, timestamp_ms)',
        );
        await _createRoutesTable(db);
        await _createRouteLoopsTable(db);
        await _createCameraEventsTable(db);
        await _createRideEngineLabelsTable(db);
        await _createLeanLabSessionsTable(db);
        await _createSyncOutboxTable(db);
        await _createLeanSamplesTable(db);
        await _createImuSamplesTable(db);
        await _createImuUploadsTable(db);
        await _createRidePhotosTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE rides ADD COLUMN max_lean_degrees REAL',
          );
          await db.execute(
            'ALTER TABLE track_points ADD COLUMN lean_degrees REAL',
          );
        }
        if (oldVersion < 3) {
          await _createRoutesTable(db);
          await db.execute('ALTER TABLE rides ADD COLUMN route_id TEXT');
          await db.execute(
            'ALTER TABLE rides ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 1',
          );
        }
        if (oldVersion < 4) {
          await _addLoopColumnsIfMissing(db);
        }
        if (oldVersion < 5) {
          await _createRouteLoopsTable(db);
          await _migrateRouteAnchorsToLoops(db);
        }
        if (oldVersion < 6) {
          // Product reset: drop saved loops + A/B anchors on every device.
          await _clearAllLoopData(db);
        }
        if (oldVersion < 7) {
          await _addOwnerIdColumnIfMissing(db);
        }
        if (oldVersion < 8) {
          await _createCameraEventsTable(db);
        }
        if (oldVersion < 9) {
          await _addTelemetryCategoryColumnIfMissing(db);
        }
        if (oldVersion < 10) {
          await _addVisibilityColumnsIfMissing(db);
        }
        if (oldVersion < 11) {
          await _addRideTitleColumnIfMissing(db);
        }
        if (oldVersion < 12) {
          await _createRideEngineLabelsTable(db);
        }
        if (oldVersion < 13) {
          await _createLeanLabSessionsTable(db);
        }
        if (oldVersion < 14) {
          await _addLeanLabBikeIdColumnIfMissing(db);
        }
        if (oldVersion < 15) {
          await _addPressureColumnIfMissing(db);
        }
        if (oldVersion < 16) {
          await _createSyncOutboxTable(db);
        }
        if (oldVersion < 17) {
          await _addLeanFreezeColumnsIfMissing(db);
          await _createLeanSamplesTable(db);
        }
        if (oldVersion < 18) {
          await _createRidePhotosTable(db);
        }
        if (oldVersion < 19) {
          await _addLeanSampleReplayColumnsIfMissing(db);
          await _createImuSamplesTable(db);
        }
        if (oldVersion < 20) {
          await _createImuUploadsTable(db);
        }
      },
    );
  }

  Future<void> _createLeanSamplesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lean_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        lean_degrees REAL NOT NULL,
        gps_lean_degrees REAL,
        speed_mps REAL,
        confidence REAL,
        vector_lean REAL,
        pose TEXT,
        fused_roll REAL,
        fused_pitch REAL,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lean_samples_ride '
      'ON lean_samples(ride_id, timestamp_ms)',
    );
  }

  Future<void> _addLeanSampleReplayColumnsIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(lean_samples)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    Future<void> add(String name, String sqlType) async {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE lean_samples ADD COLUMN $name $sqlType');
      }
    }

    await add('vector_lean', 'REAL');
    await add('pose', 'TEXT');
    await add('fused_roll', 'REAL');
    await add('fused_pitch', 'REAL');
  }

  Future<void> _createImuSamplesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS imu_samples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        timestamp_ms INTEGER NOT NULL,
        ax REAL NOT NULL,
        ay REAL NOT NULL,
        az REAL NOT NULL,
        gx REAL NOT NULL,
        gy REAL NOT NULL,
        gz REAL NOT NULL,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_imu_samples_ride '
      'ON imu_samples(ride_id, timestamp_ms)',
    );
  }

  Future<void> _addLeanFreezeColumnsIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(rides)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    Future<void> add(String name, String sqlType) async {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE rides ADD COLUMN $name $sqlType');
      }
    }

    await add('lean_upright_locked', 'INTEGER NOT NULL DEFAULT 0');
    await add('lean_g0_x', 'REAL');
    await add('lean_g0_y', 'REAL');
    await add('lean_g0_z', 'REAL');
    await add('lean_pose_class', 'TEXT');
    await add('lean_sign_flip', 'INTEGER NOT NULL DEFAULT 1');
    await add('lean_freeze_at_ms', 'INTEGER');
    await add('lean_mount_mode', 'TEXT');
  }

  Future<void> _createSyncOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        ride_local_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        next_attempt_at_ms INTEGER,
        last_error TEXT,
        chunk_index INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending '
      'ON sync_outbox(status, next_attempt_at_ms, created_at_ms)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_ride '
      'ON sync_outbox(ride_local_id, kind)',
    );
  }

  Future<void> _addPressureColumnIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(track_points)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    if (!existing.contains('pressure_hpa')) {
      await db.execute('ALTER TABLE track_points ADD COLUMN pressure_hpa REAL');
    }
  }

  Future<void> _createLeanLabSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lean_lab_sessions (
        ride_id TEXT PRIMARY KEY,
        protocol_id TEXT NOT NULL,
        session_type TEXT NOT NULL,
        direction TEXT NOT NULL,
        phone_mount TEXT NOT NULL,
        phone_pose TEXT NOT NULL,
        frozen_neutral_deg REAL NOT NULL,
        calib_at_ms INTEGER,
        corners_json TEXT NOT NULL DEFAULT '[]',
        coverage_pct REAL NOT NULL DEFAULT 0,
        total_climb_m REAL NOT NULL DEFAULT 0,
        total_descent_m REAL NOT NULL DEFAULT 0,
        bike_id TEXT,
        created_at_ms INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lean_lab_synced '
      'ON lean_lab_sessions(synced, created_at_ms)',
    );
  }

  Future<void> _addLeanLabBikeIdColumnIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(lean_lab_sessions)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    if (!existing.contains('bike_id')) {
      await db.execute('ALTER TABLE lean_lab_sessions ADD COLUMN bike_id TEXT');
    }
  }

  Future<void> _createRideEngineLabelsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ride_engine_labels (
        ride_id TEXT PRIMARY KEY,
        phone_mount TEXT NOT NULL,
        lean_quality TEXT,
        brake_feel TEXT,
        ride_context TEXT,
        notes TEXT,
        skipped INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ride_engine_labels_synced '
      'ON ride_engine_labels(synced, created_at_ms)',
    );
  }

  Future<void> _addRideTitleColumnIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(rides)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    if (!existing.contains('title')) {
      await db.execute('ALTER TABLE rides ADD COLUMN title TEXT');
    }
  }

  Future<void> _addVisibilityColumnsIfMissing(Database db) async {
    Future<void> addVis(String table) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      final existing = columns.map((c) => c['name'] as String).toSet();
      if (!existing.contains('visibility')) {
        await db.execute(
          "ALTER TABLE $table ADD COLUMN visibility TEXT NOT NULL DEFAULT 'friends'",
        );
        // Preserve prior share flag: shared → public, else private.
        await db.execute(
          "UPDATE $table SET visibility = CASE WHEN is_shared = 1 THEN 'public' ELSE 'private' END",
        );
      }
    }

    await addVis('rides');
    await addVis('routes');
  }

  Future<void> _createCameraEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS camera_events (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL DEFAULT 'camera',
        ride_local_id TEXT,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL DEFAULT '{}',
        latitude REAL,
        longitude REAL,
        created_at_ms INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_camera_events_synced '
      'ON camera_events(synced, created_at_ms)',
    );
  }

  Future<void> _addTelemetryCategoryColumnIfMissing(Database db) async {
    await _createCameraEventsTable(db);
    final columns = await db.rawQuery('PRAGMA table_info(camera_events)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    if (!existing.contains('category')) {
      await db.execute(
        "ALTER TABLE camera_events ADD COLUMN category TEXT NOT NULL DEFAULT 'camera'",
      );
    }
  }

  Future<void> insertTelemetryEvent({
    required String id,
    required String category,
    String? rideLocalId,
    required String eventType,
    required String payloadJson,
    double? latitude,
    double? longitude,
    required int createdAtMs,
  }) async {
    final db = await database;
    await db.insert('camera_events', {
      'id': id,
      'category': category,
      'ride_local_id': rideLocalId,
      'event_type': eventType,
      'payload_json': payloadJson,
      'latitude': latitude,
      'longitude': longitude,
      'created_at_ms': createdAtMs,
      'synced': 0,
    });
  }

  /// Legacy name — camera lab still calls this.
  Future<void> insertCameraEvent({
    required String id,
    String? rideLocalId,
    required String eventType,
    required String payloadJson,
    double? latitude,
    double? longitude,
    required int createdAtMs,
    String category = 'camera',
  }) {
    return insertTelemetryEvent(
      id: id,
      category: category,
      rideLocalId: rideLocalId,
      eventType: eventType,
      payloadJson: payloadJson,
      latitude: latitude,
      longitude: longitude,
      createdAtMs: createdAtMs,
    );
  }

  Future<List<Map<String, Object?>>> listUnsyncedTelemetryEvents({
    int limit = 300,
  }) async {
    final db = await database;
    return db.query(
      'camera_events',
      where: 'synced = 0',
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, Object?>>> listUnsyncedCameraEvents({
    int limit = 200,
  }) =>
      listUnsyncedTelemetryEvents(limit: limit);

  Future<void> markTelemetryEventsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE camera_events SET synced = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  Future<void> upsertRideEngineLabel(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'ride_engine_labels',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getRideEngineLabel(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'ride_engine_labels',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> listUnsyncedRideEngineLabels({
    int limit = 100,
  }) async {
    final db = await database;
    return db.query(
      'ride_engine_labels',
      where: 'synced = 0 AND skipped = 0',
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  Future<void> markRideEngineLabelsSynced(List<String> rideIds) async {
    if (rideIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(rideIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE ride_engine_labels SET synced = 1 WHERE ride_id IN ($placeholders)',
      rideIds,
    );
  }

  Future<void> upsertLeanLabSession(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'lean_lab_sessions',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getLeanLabSession(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'lean_lab_sessions',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> listLeanLabSessions({int limit = 40}) async {
    final db = await database;
    return db.query(
      'lean_lab_sessions',
      orderBy: 'created_at_ms DESC',
      limit: limit,
    );
  }

  Future<void> markLeanLabSessionsSynced(List<String> rideIds) async {
    if (rideIds.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(rideIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE lean_lab_sessions SET synced = 1 WHERE ride_id IN ($placeholders)',
      rideIds,
    );
  }

  Future<void> markCameraEventsSynced(List<String> ids) =>
      markTelemetryEventsSynced(ids);

  Future<void> _addOwnerIdColumnIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(routes)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    if (!existing.contains('owner_id')) {
      await db.execute('ALTER TABLE routes ADD COLUMN owner_id TEXT');
    }
  }

  Future<void> _clearAllLoopData(Database db) async {
    await _createRouteLoopsTable(db);
    await db.delete('route_loops');
    await db.update('routes', {
      'init_lat': null,
      'init_lng': null,
      'end_lat': null,
      'end_lng': null,
      'geofence_radius_m': null,
    });
  }

  Future<void> deleteLoopsForRoute(String routeId) async {
    final db = await database;
    await db.delete('route_loops', where: 'route_id = ?', whereArgs: [routeId]);
  }

  Future<void> _createRouteLoopsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS route_loops (
        id TEXT PRIMARY KEY,
        route_id TEXT NOT NULL,
        name TEXT NOT NULL,
        init_lat REAL NOT NULL,
        init_lng REAL NOT NULL,
        end_lat REAL NOT NULL,
        end_lng REAL NOT NULL,
        geofence_radius_m REAL NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at_ms INTEGER NOT NULL,
        source_ride_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_route_loops_route ON route_loops(route_id)',
    );
  }

  /// One-time: turn legacy route init/end columns into a primary RouteLoop.
  Future<void> _migrateRouteAnchorsToLoops(Database db) async {
    final routes = await db.query('routes');
    for (final row in routes) {
      final initLat = row['init_lat'] as num?;
      final initLng = row['init_lng'] as num?;
      final endLat = row['end_lat'] as num?;
      final endLng = row['end_lng'] as num?;
      if (initLat == null ||
          initLng == null ||
          endLat == null ||
          endLng == null) {
        continue;
      }
      final routeId = row['id'] as String;
      final existing = await db.query(
        'route_loops',
        where: 'route_id = ?',
        whereArgs: [routeId],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await db.insert('route_loops', {
        'id': '${routeId}_legacy_loop',
        'route_id': routeId,
        'name': 'Principal',
        'init_lat': initLat.toDouble(),
        'init_lng': initLng.toDouble(),
        'end_lat': endLat.toDouble(),
        'end_lng': endLng.toDouble(),
        'geofence_radius_m':
            (row['geofence_radius_m'] as num?)?.toDouble() ?? 50.0,
        'source': 'manual',
        'created_at_ms': DateTime.now().millisecondsSinceEpoch,
        'source_ride_id': null,
        'is_primary': 1,
      });
    }
  }

  Future<void> _createRoutesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_shared INTEGER NOT NULL DEFAULT 0,
        visibility TEXT NOT NULL DEFAULT 'friends',
        created_at_ms INTEGER NOT NULL,
        owner_id TEXT,
        init_lat REAL,
        init_lng REAL,
        end_lat REAL,
        end_lng REAL,
        geofence_radius_m REAL
      )
    ''');
  }

  /// Fresh installs create `routes` with loop columns already present, but a
  /// v1-2 -> v3 upgrade path may have created it without them (table was
  /// created fresh at v3 with the old CREATE TABLE shape at upgrade time).
  Future<void> _addLoopColumnsIfMissing(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(routes)');
    final existing = columns.map((c) => c['name'] as String).toSet();
    Future<void> addIfMissing(String name, String type) async {
      if (!existing.contains(name)) {
        await db.execute('ALTER TABLE routes ADD COLUMN $name $type');
      }
    }

    await addIfMissing('init_lat', 'REAL');
    await addIfMissing('init_lng', 'REAL');
    await addIfMissing('end_lat', 'REAL');
    await addIfMissing('end_lng', 'REAL');
    await addIfMissing('geofence_radius_m', 'REAL');
  }

  Future<void> upsertRide(Ride ride) async {
    final db = await database;
    await db.insert(
      'rides',
      ride.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertPoint(TrackPoint point) async {
    final db = await database;
    await db.insert('track_points', point.toMap()..remove('id'));
  }

  Future<void> insertPointsBatch(List<TrackPoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final point in points) {
      batch.insert('track_points', point.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  /// Replace all GPS samples for a ride (used by cloud pull).
  Future<void> replacePointsForRide(
    String rideId,
    List<TrackPoint> points,
  ) async {
    final db = await database;
    await db.delete('track_points', where: 'ride_id = ?', whereArgs: [rideId]);
    if (points.isEmpty) return;
    await insertPointsBatch(points);
  }

  Future<List<Ride>> listRides() async {
    final db = await database;
    final rows = await db.query(
      'rides',
      orderBy: 'started_at_ms DESC',
    );
    return rows.map(Ride.fromMap).toList();
  }

  Future<Ride?> getRide(String id) async {
    final db = await database;
    final rows = await db.query(
      'rides',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ride.fromMap(rows.first);
  }

  Future<List<Ride>> listRidesForRoute(String routeId) async {
    final db = await database;
    final rows = await db.query(
      'rides',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'started_at_ms DESC',
    );
    return rows.map(Ride.fromMap).toList();
  }

  Future<Ride?> getActiveRide() async {
    final db = await database;
    final rows = await db.query(
      'rides',
      where: 'status = ?',
      whereArgs: [RideStatus.recording.name],
      orderBy: 'started_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Ride.fromMap(rows.first);
  }

  Future<List<TrackPoint>> getPoints(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'track_points',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(TrackPoint.fromMap).toList();
  }

  Future<void> deleteRide(String id) async {
    final db = await database;
    await db.delete('track_points', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('lean_samples', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('imu_samples', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('imu_uploads', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('ride_photos', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('rides', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertRoute(RouteCircuit route) async {
    final db = await database;
    await db.insert(
      'routes',
      route.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RouteCircuit>> listRoutes() async {
    final db = await database;
    final rows = await db.query('routes', orderBy: 'created_at_ms DESC');
    return rows.map(RouteCircuit.fromMap).toList();
  }

  /// Routes owned by [ownerId], plus legacy local rows with no owner.
  Future<List<RouteCircuit>> listMyRoutes(String? ownerId) async {
    final all = await listRoutes();
    if (ownerId == null || ownerId.isEmpty) return all;
    return all
        .where((r) => r.ownerId == null || r.ownerId == ownerId)
        .toList();
  }

  Future<RouteCircuit?> getRoute(String id) async {
    final db = await database;
    final rows = await db.query(
      'routes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RouteCircuit.fromMap(rows.first);
  }

  Future<void> deleteRoute(String id) async {
    final db = await database;
    await db.update(
      'rides',
      {'route_id': null},
      where: 'route_id = ?',
      whereArgs: [id],
    );
    await db.delete('route_loops', where: 'route_id = ?', whereArgs: [id]);
    await db.delete('routes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> upsertLoop(RouteLoop loop) async {
    final db = await database;
    await db.insert(
      'route_loops',
      loop.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RouteLoop>> listLoopsForRoute(String routeId) async {
    final db = await database;
    final rows = await db.query(
      'route_loops',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'is_primary DESC, created_at_ms DESC',
    );
    return rows.map(RouteLoop.fromMap).toList();
  }

  Future<RouteLoop?> getLoop(String id) async {
    final db = await database;
    final rows = await db.query(
      'route_loops',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return RouteLoop.fromMap(rows.first);
  }

  Future<RouteLoop?> getPrimaryLoop(String routeId) async {
    final db = await database;
    final rows = await db.query(
      'route_loops',
      where: 'route_id = ? AND is_primary = 1',
      whereArgs: [routeId],
      limit: 1,
    );
    if (rows.isNotEmpty) return RouteLoop.fromMap(rows.first);
    final any = await listLoopsForRoute(routeId);
    return any.isEmpty ? null : any.first;
  }

  Future<void> clearPrimaryLoops(String routeId) async {
    final db = await database;
    await db.update(
      'route_loops',
      {'is_primary': 0},
      where: 'route_id = ?',
      whereArgs: [routeId],
    );
  }

  Future<void> deleteLoop(String id) async {
    final db = await database;
    await db.delete('route_loops', where: 'id = ?', whereArgs: [id]);
  }

  // --- Sync outbox ---------------------------------------------------------

  Future<List<Map<String, dynamic>>> listPendingSyncOutbox({
    required int nowMs,
    int limit = 20,
  }) async {
    final db = await database;
    return db.query(
      'sync_outbox',
      where: "status IN ('pending', 'failed') AND "
          '(next_attempt_at_ms IS NULL OR next_attempt_at_ms <= ?)',
      whereArgs: [nowMs],
      orderBy: 'created_at_ms ASC',
      limit: limit,
    );
  }

  Future<void> upsertSyncOutboxItem(Map<String, dynamic> row) async {
    final db = await database;
    await db.insert(
      'sync_outbox',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSyncOutboxStatus({
    required String id,
    required String status,
    int? attempts,
    int? nextAttemptAtMs,
    String? lastError,
  }) async {
    final db = await database;
    await db.update(
      'sync_outbox',
      {
        'status': status,
        if (attempts != null) 'attempts': attempts,
        'next_attempt_at_ms': nextAttemptAtMs,
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSyncOutboxItem(String id) async {
    final db = await database;
    await db.delete('sync_outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteDoneSyncOutboxForRide(String rideLocalId) async {
    final db = await database;
    await db.delete(
      'sync_outbox',
      where: "ride_local_id = ? AND status = 'done'",
      whereArgs: [rideLocalId],
    );
  }

  Future<bool> hasPendingSyncOutboxForRide(String rideLocalId) async {
    final db = await database;
    final rows = await db.query(
      'sync_outbox',
      columns: ['id'],
      where: "ride_local_id = ? AND status IN ('pending', 'in_flight', 'failed')",
      whereArgs: [rideLocalId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // --- Lean samples (10 Hz series) ----------------------------------------

  Future<void> insertLeanSamplesBatch(List<LeanSample> samples) async {
    if (samples.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final s in samples) {
      batch.insert('lean_samples', s.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<LeanSample>> getLeanSamples(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'lean_samples',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(LeanSample.fromMap).toList();
  }

  Future<void> deleteLeanSamplesForRide(String rideId) async {
    final db = await database;
    await db.delete('lean_samples', where: 'ride_id = ?', whereArgs: [rideId]);
  }

  // --- IMU samples (~50 Hz raw 6-axis, local replay) ----------------------

  Future<void> insertImuSamplesBatch(List<RideImuSample> samples) async {
    if (samples.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final s in samples) {
      batch.insert('imu_samples', s.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<List<RideImuSample>> getImuSamples(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'imu_samples',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'timestamp_ms ASC',
    );
    return rows.map(RideImuSample.fromMap).toList();
  }

  Future<void> deleteImuSamplesForRide(String rideId) async {
    final db = await database;
    await db.delete('imu_samples', where: 'ride_id = ?', whereArgs: [rideId]);
  }

  Future<void> _createImuUploadsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS imu_uploads (
        ride_id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        blob_path TEXT,
        error TEXT,
        updated_at_ms INTEGER NOT NULL,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> upsertImuUpload(ImuUploadRow row) async {
    final db = await database;
    await db.insert(
      'imu_uploads',
      row.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ImuUploadRow?> getImuUpload(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'imu_uploads',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ImuUploadRow.fromMap(rows.first);
  }

  // --- Ride photos (offline queue → rodada album) -------------------------

  Future<void> _createRidePhotosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ride_photos (
        id TEXT PRIMARY KEY,
        ride_id TEXT NOT NULL,
        rodada_id TEXT,
        local_path TEXT,
        storage_path TEXT,
        taken_at_ms INTEGER,
        latitude REAL,
        longitude REAL,
        source TEXT,
        content_hash TEXT,
        uploaded INTEGER NOT NULL DEFAULT 0,
        created_at_ms INTEGER NOT NULL,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ride_photos_ride '
      'ON ride_photos(ride_id, taken_at_ms)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ride_photos_pending '
      'ON ride_photos(uploaded, ride_id)',
    );
  }

  Future<void> upsertRidePhoto(RidePhoto photo) async {
    final db = await database;
    await db.insert(
      'ride_photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RidePhoto>> getRidePhotos(String rideId) async {
    final db = await database;
    final rows = await db.query(
      'ride_photos',
      where: 'ride_id = ?',
      orderBy: 'taken_at_ms ASC, created_at_ms ASC',
      whereArgs: [rideId],
    );
    return rows.map(RidePhoto.fromMap).toList();
  }

  Future<List<RidePhoto>> getPendingRidePhotos({String? rideId}) async {
    final db = await database;
    final rows = rideId == null
        ? await db.query(
            'ride_photos',
            where: 'uploaded = 0',
            orderBy: 'created_at_ms ASC',
          )
        : await db.query(
            'ride_photos',
            where: 'uploaded = 0 AND ride_id = ?',
            whereArgs: [rideId],
            orderBy: 'created_at_ms ASC',
          );
    return rows.map(RidePhoto.fromMap).toList();
  }

  Future<bool> ridePhotoHashExists(String contentHash) async {
    final db = await database;
    final rows = await db.query(
      'ride_photos',
      columns: ['id'],
      where: 'content_hash = ?',
      whereArgs: [contentHash],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> markRidePhotoUploaded({
    required String id,
    required String storagePath,
    String? rodadaId,
  }) async {
    final db = await database;
    await db.update(
      'ride_photos',
      {
        'uploaded': 1,
        'storage_path': storagePath,
        'rodada_id': ?rodadaId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setRidePhotosRodada({
    required String rideId,
    required String rodadaId,
  }) async {
    final db = await database;
    await db.update(
      'ride_photos',
      {'rodada_id': rodadaId},
      where: 'ride_id = ?',
      whereArgs: [rideId],
    );
  }
}
