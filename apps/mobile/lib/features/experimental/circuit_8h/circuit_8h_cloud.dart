import 'package:flutter/foundation.dart';

import '../../../core/services/rider_telemetry_service.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/telemetry/labels/ride_engine_label.dart';
import 'circuit_8h_models.dart';
import 'circuit_8h_store.dart';

/// Uploads Circuito 8h project + each pass to Supabase for remote analysis.
///
/// Dual-write (same pattern as Lean Lab):
/// - `ride_engine_labels` — full JSON for SQL / notebooks
/// - `camera_events` via telemetry — backup channel
class Circuit8hCloudUpload {
  Circuit8hCloudUpload._();

  static const schema = 'circuit_8h.v1';
  static const projectLocalId = 'circuit_8h_project_v1';

  /// Returns how many rows were upserted (project + sessions), or throws.
  static Future<Circuit8hUploadResult> upload({
    Circuit8hProject? project,
  }) async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Cloud no está listo');
    }
    final session = await SupabaseBootstrap.ensureSession();
    if (session == null) {
      throw StateError(
        SupabaseBootstrap.lastAuthError ?? 'Inicia sesión para subir',
      );
    }
    final userId = SupabaseBootstrap.permanentUserId;
    if (userId == null) {
      throw StateError('Inicia sesión con una cuenta real (no anónima)');
    }

    final data = project ?? await loadCircuit8hProject();
    if (data.sessions.isEmpty &&
        data.start == null &&
        data.finish == null &&
        data.checkpoints.isEmpty) {
      throw StateError('No hay datos del Circuito 8h para subir');
    }

    final uploadedAt = DateTime.now().toUtc().toIso8601String();
    final client = SupabaseBootstrap.client;
    var upserts = 0;

    final projectPayload = <String, dynamic>{
      'schema': schema,
      'kind': 'project',
      'uploadedAt': uploadedAt,
      'userId': userId,
      ...Map<String, dynamic>.from(data.toJson()),
    };

    await client.from('ride_engine_labels').upsert(
      {
        'user_id': userId,
        'ride_local_id': projectLocalId,
        'phone_mount': 'circuit_8h',
        'lean_quality': null,
        'brake_feel': null,
        'ride_context': RideContextId.track,
        'notes': 'circuit_8h:project',
        'payload': projectPayload,
        'labeled_at': uploadedAt,
      },
      onConflict: 'user_id,ride_local_id',
    );
    upserts++;

    await RiderTelemetryService.instance.log(
      category: TelemetryCategory.circuit8h,
      eventType: 'circuit_8h_project',
      rideLocalId: projectLocalId,
      payload: projectPayload,
    );

    for (final s in data.sessions) {
      final localId = 'circuit_8h_pass_${s.id}';
      final passPayload = <String, dynamic>{
        'schema': schema,
        'kind': 'pass',
        'uploadedAt': uploadedAt,
        'userId': userId,
        'projectName': data.name,
        'start': data.start?.toJson(),
        'finish': data.finish?.toJson(),
        'checkpoints': [for (final c in data.checkpoints) c.toJson()],
        'session': s.toJson(),
      };
      try {
        await client.from('ride_engine_labels').upsert(
          {
            'user_id': userId,
            'ride_local_id': localId,
            'phone_mount': 'circuit_8h',
            'lean_quality': null,
            'brake_feel': null,
            'ride_context': RideContextId.track,
            'notes': 'circuit_8h:pass:${s.routeType.id}',
            'payload': passPayload,
            'labeled_at': uploadedAt,
          },
          onConflict: 'user_id,ride_local_id',
        );
        upserts++;
      } catch (e) {
        debugPrint('Circuit8h pass upsert $localId: $e');
        rethrow;
      }

      await RiderTelemetryService.instance.log(
        category: TelemetryCategory.circuit8h,
        eventType: 'circuit_8h_pass',
        rideLocalId: localId,
        payload: {
          'schema': schema,
          'sessionId': s.id,
          'routeType': s.routeType.id,
          'pointCount': s.pointCount,
          'startedAtMs': s.startedAtMs,
          'endedAtMs': s.endedAtMs,
        },
      );
    }

    await saveCircuit8hLastUploadAt(uploadedAt);

    return Circuit8hUploadResult(
      upserts: upserts,
      passCount: data.sessions.length,
      uploadedAt: uploadedAt,
      userId: userId,
    );
  }
}

class Circuit8hUploadResult {
  const Circuit8hUploadResult({
    required this.upserts,
    required this.passCount,
    required this.uploadedAt,
    required this.userId,
  });

  final int upserts;
  final int passCount;
  final String uploadedAt;
  final String userId;
}
