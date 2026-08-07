import 'package:flutter/foundation.dart';

import '../analytics/ride_analytics.dart';
import '../db/ride_database.dart';
import '../models/track_point.dart';
import '../services/rider_telemetry_service.dart';
import '../supabase/supabase_bootstrap.dart';
import '../telemetry/labels/ride_engine_label.dart';
import 'grade_profile.dart';
import 'lean_lab_circuit.dart';
import 'lean_lab_models.dart';

class LeanLabService {
  LeanLabService({
    RideDatabase? database,
    RiderTelemetryService? telemetry,
  })  : _db = database ?? RideDatabase.instance,
        _telemetry = telemetry ?? RiderTelemetryService.instance;

  static final LeanLabService instance = LeanLabService();

  final RideDatabase _db;
  final RiderTelemetryService _telemetry;

  Future<LeanLabSession?> getSession(String rideId) async {
    final row = await _db.getLeanLabSession(rideId);
    if (row == null) return null;
    return LeanLabSession.fromDb(row);
  }

  Future<List<LeanLabSession>> listSessions({int limit = 40}) async {
    final rows = await _db.listLeanLabSessions(limit: limit);
    return [for (final r in rows) LeanLabSession.fromDb(r)];
  }

  Future<void> saveSession(LeanLabSession session, {RideAnalytics? analytics}) async {
    await _db.upsertLeanLabSession(session.toDb());
    final payload = session.toTrainingPayload(
      pointCount: analytics?.samples.length,
      distanceKm: analytics?.distanceKm,
    );
    await _telemetry.log(
      category: TelemetryCategory.leanLab,
      eventType: 'lean_lab_session',
      rideLocalId: session.rideId,
      payload: payload,
    );
    try {
      await _upsertCloud(session, payload);
      await _db.markLeanLabSessionsSynced([session.rideId]);
      await _telemetry.flushPending();
    } catch (e) {
      debugPrint('LeanLab sync: $e');
    }
  }

  /// Attach a new Lean Lab session right after ride start.
  Future<LeanLabSession> beginSession({
    required String rideId,
    required LeanLabSessionType sessionType,
    required LeanLabDirection direction,
    required String phoneMount,
    required PhonePoseId phonePose,
    required double frozenNeutralDeg,
    DateTime? calibAt,
    String? bikeId,
  }) async {
    final session = LeanLabSession(
      rideId: rideId,
      protocolId: BugambiliasCircuit.protocolId,
      sessionType: sessionType,
      direction: direction,
      phoneMount: phoneMount,
      phonePose: phonePose,
      frozenNeutralDeg: frozenNeutralDeg,
      calibAt: calibAt ?? DateTime.now(),
      bikeId: bikeId,
      createdAt: DateTime.now(),
    );
    await saveSession(session);
    return session;
  }

  /// After ride ends: fill coverage, elevation, inferred direction if unknown.
  Future<LeanLabSession?> finalizeTrackStats({
    required String rideId,
    required List<TrackPoint> samples,
  }) async {
    final existing = await getSession(rideId);
    if (existing == null) return null;
    final grade = buildGradeProfile(samples);
    var direction = existing.direction;
    if (direction == LeanLabDirection.unknown &&
        BugambiliasCircuit.trackOverlaps(samples)) {
      direction = BugambiliasCircuit.inferDirection(samples);
    }
    final updated = existing.copyWith(
      coveragePct: BugambiliasCircuit.coveragePct(samples),
      totalClimbM: grade.totalClimbMeters,
      totalDescentM: grade.totalDescentMeters,
      direction: direction,
      synced: false,
    );
    await saveSession(updated);
    return updated;
  }

  Future<void> saveCornerLabels({
    required String rideId,
    required List<LeanLabCornerLabel> corners,
    RideAnalytics? analytics,
  }) async {
    final existing = await getSession(rideId);
    if (existing == null) return;
    await saveSession(
      existing.copyWith(corners: corners, synced: false),
      analytics: analytics,
    );
  }

  /// Fix mistaken prep choices (ida/vuelta, mount, pose, protocol) after the ride.
  Future<LeanLabSession?> updateSessionConfig({
    required String rideId,
    LeanLabSessionType? sessionType,
    LeanLabDirection? direction,
    String? phoneMount,
    PhonePoseId? phonePose,
  }) async {
    final existing = await getSession(rideId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      sessionType: sessionType,
      direction: direction,
      phoneMount: phoneMount,
      phonePose: phonePose,
      synced: false,
    );
    await saveSession(updated);
    return updated;
  }

  /// Suggested default mount for a session type.
  static String defaultMount(LeanLabSessionType type) =>
      type == LeanLabSessionType.mountPocket
          ? PhoneMountId.leftPocket
          : PhoneMountId.centerMount;

  static LeanLabDirection defaultDirection(LeanLabSessionType type) =>
      switch (type) {
        LeanLabSessionType.baselineOutbound => LeanLabDirection.outbound,
        LeanLabSessionType.baselineReturn => LeanLabDirection.returnTrip,
        _ => LeanLabDirection.unknown,
      };

  Future<void> _upsertCloud(
    LeanLabSession session,
    Map<String, dynamic> payload,
  ) async {
    if (!SupabaseBootstrap.isReady) return;
    final userId = SupabaseBootstrap.client.auth.currentUser?.id;
    if (userId == null) return;
    // Reuse ride_engine_labels payload channel with lean_lab schema marker,
    // and also log telemetry — avoids a blocking migration for pilots.
    await SupabaseBootstrap.client.from('ride_engine_labels').upsert({
      'user_id': userId,
      'ride_local_id': '${session.rideId}__lean_lab',
      'phone_mount': session.phoneMount,
      'lean_quality': null,
      'brake_feel': null,
      'ride_context': RideContextId.mountain,
      'notes': 'lean_lab:${session.protocolId}',
      'payload': payload,
      'labeled_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
