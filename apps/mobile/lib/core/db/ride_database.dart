import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ride.dart';
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
      version: 7,
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
            is_shared INTEGER NOT NULL DEFAULT 1
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
            timestamp_ms INTEGER NOT NULL,
            FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_points_ride ON track_points(ride_id, timestamp_ms)',
        );
        await _createRoutesTable(db);
        await _createRouteLoopsTable(db);
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
      },
    );
  }

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
}
