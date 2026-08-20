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

  String? lastPullInfo;
  String? lastPullError;

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

  /// Download this account's Lean Lab sessions from cloud into local SQLite.
  /// Prefer structured `ride_engine_labels`; fall back to `camera_events`
  /// (where Bugambilias pilot data actually landed).
  Future<int> pullMyCloudSessions({int limit = 80}) async {
    lastPullError = null;
    lastPullInfo = null;
    if (!SupabaseBootstrap.isReady) {
      lastPullError = 'Cloud not configured';
      return 0;
    }

    try {
      await SupabaseBootstrap.ensureSession();
      final userId = SupabaseBootstrap.client.auth.currentUser?.id;
      if (userId == null) {
        lastPullError =
            SupabaseBootstrap.lastAuthError ?? 'Not signed in to cloud';
        return 0;
      }

      final byRide = <String, LeanLabSession>{};

      // Primary channel (may be missing on older remote projects).
      try {
        final rows = await SupabaseBootstrap.client
            .from('ride_engine_labels')
            .select('ride_local_id, payload, labeled_at, notes')
            .eq('user_id', userId)
            .like('notes', 'lean_lab:%')
            .order('labeled_at', ascending: false)
            .limit(limit);
        for (final raw in (rows as List)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final payload = _asMap(map['payload']);
          if (payload == null) continue;
          if (payload['schema'] != 'lean_lab.v1' &&
              !(map['notes'] as String? ?? '').startsWith('lean_lab:')) {
            continue;
          }
          final rideLocal = map['ride_local_id'] as String?;
          final fallbackRideId = _stripLeanLabSuffix(rideLocal);
          final session = LeanLabSession.fromTrainingPayload(
            payload,
            fallbackRideId: fallbackRideId,
          );
          if (session == null) continue;
          _keepRicher(byRide, session);
        }
      } catch (e) {
        debugPrint('LeanLab pull labels: $e');
      }

      // Fallback / merge: telemetry events (always present for pilots).
      try {
        final rows = await SupabaseBootstrap.client
            .from('camera_events')
            .select('ride_local_id, payload, created_at')
            .eq('user_id', userId)
            .eq('category', TelemetryCategory.leanLab)
            .eq('event_type', 'lean_lab_session')
            .order('created_at', ascending: false)
            .limit(limit * 3);
        for (final raw in (rows as List)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final payload = _asMap(map['payload']);
          if (payload == null) continue;
          if (payload['schema'] != null && payload['schema'] != 'lean_lab.v1') {
            continue;
          }
          final session = LeanLabSession.fromTrainingPayload(
            payload,
            fallbackRideId: map['ride_local_id'] as String?,
          );
          if (session == null) continue;
          _keepRicher(byRide, session);
        }
      } catch (e) {
        debugPrint('LeanLab pull telemetry: $e');
      }

      var imported = 0;
      for (final session in byRide.values) {
        final existing = await getSession(session.rideId);
        if (existing != null &&
            existing.corners.length >= session.corners.length &&
            existing.coveragePct >= session.coveragePct) {
          // Keep local if it already has equal/better data.
          continue;
        }
        await _db.upsertLeanLabSession(session.toDb());
        imported++;
      }

      lastPullInfo = 'Pulled $imported Lean Lab session(s)';
      return imported;
    } catch (e) {
      lastPullError = SupabaseBootstrap.lastAuthError ?? '$e';
      debugPrint('LeanLab pull sessions: $e');
      return 0;
    }
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  static String? _stripLeanLabSuffix(String? rideLocalId) {
    if (rideLocalId == null) return null;
    const suffix = '__lean_lab';
    if (rideLocalId.endsWith(suffix)) {
      return rideLocalId.substring(0, rideLocalId.length - suffix.length);
    }
    return rideLocalId;
  }

  static void _keepRicher(
    Map<String, LeanLabSession> byRide,
    LeanLabSession candidate,
  ) {
    final prev = byRide[candidate.rideId];
    if (prev == null) {
      byRide[candidate.rideId] = candidate;
      return;
    }
    // Prefer more corner labels, then higher coverage, then newer createdAt.
    if (candidate.corners.length > prev.corners.length) {
      byRide[candidate.rideId] = candidate;
      return;
    }
    if (candidate.corners.length == prev.corners.length &&
        candidate.coveragePct > prev.coveragePct) {
      byRide[candidate.rideId] = candidate;
      return;
    }
    final cAt = candidate.createdAt;
    final pAt = prev.createdAt;
    if (candidate.corners.length == prev.corners.length &&
        candidate.coveragePct == prev.coveragePct &&
        cAt != null &&
        (pAt == null || cAt.isAfter(pAt))) {
      byRide[candidate.rideId] = candidate;
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
  static String defaultMount(LeanLabSessionType type) => switch (type) {
        _ => PhoneMountId.centerMount,
      };

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
    try {
      await SupabaseBootstrap.client.from('ride_engine_labels').upsert(
        {
          'user_id': userId,
          'ride_local_id': '${session.rideId}__lean_lab',
          'phone_mount': session.phoneMount,
          'lean_quality': null,
          'brake_feel': null,
          'ride_context': RideContextId.mountain,
          'notes': 'lean_lab:${session.protocolId}',
          'payload': payload,
          'labeled_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,ride_local_id',
      );
    } catch (e) {
      // Table may be missing on older remotes; camera_events still holds data.
      debugPrint('LeanLab cloud upsert: $e');
    }
  }
}
