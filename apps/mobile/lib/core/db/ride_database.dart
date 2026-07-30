import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/ride.dart';
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
      version: 1,
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
            avg_speed_mps REAL
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
            timestamp_ms INTEGER NOT NULL,
            FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_points_ride ON track_points(ride_id, timestamp_ms)',
        );
      },
    );
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
}
