import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/notifications/push_diagnostics.dart';
import '../../core/routing/route_prefs.dart';
import '../../core/services/directions_service.dart';
import '../../core/supabase/paged_select.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import 'models/rodada_models.dart';
import 'rodada_itinerary.dart';

const rodadaSelectColumns =
    'id, host_id, title, destination, notes, meetup_lat, meetup_lng, '
    'finish_lat, finish_lng, starts_at, status, invite_code, created_at, updated_at, '
    'route_geometry, route_distance_m, route_duration_s, route_prefs, route_provider';

class RodadaInviteResult {
  const RodadaInviteResult({
    this.alreadyMember = false,
    this.sent = 0,
    this.skipped,
    this.error,
  });

  final bool alreadyMember;
  final int sent;
  final String? skipped;
  final String? error;

  bool get pushDelivered => sent > 0;

  factory RodadaInviteResult.fromFunctionData(dynamic data) {
    if (data is Map) {
      final err = data['error']?.toString();
      final detail = data['detail']?.toString();
      if (err != null && err.isNotEmpty) {
        return RodadaInviteResult(
          error: detail == null || detail.isEmpty ? err : '$err ($detail)',
        );
      }
      final sentRaw = data['sent'];
      final sent = sentRaw is int
          ? sentRaw
          : int.tryParse(sentRaw?.toString() ?? '') ?? 0;
      return RodadaInviteResult(
        sent: sent,
        skipped: data['skipped']?.toString(),
      );
    }
    return const RodadaInviteResult(error: 'bad_response');
  }
}

String _invitePushError(Object e) {
  if (e is FunctionException) {
    final details = e.details;
    if (details is Map) {
      final err = details['error']?.toString();
      final detail = details['detail']?.toString();
      if (err != null && err.isNotEmpty) {
        return detail == null || detail.isEmpty ? err : '$err ($detail)';
      }
    }
    return 'http ${e.status}';
  }
  return e.toString();
}

/// Lazy cloud access for Rodadas. Call sites should use autoDispose providers
/// so heavy tabs (live / photos / tracks) release when the user leaves.
class RodadaRepository {
  RodadaRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  final _rng = Random.secure();

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    return SupabaseBootstrap.client;
  }

  Future<void> _ensure() async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    await SupabaseBootstrap.ensureSession();
  }

  String? get currentUserId => SupabaseBootstrap.permanentUserId;

  String _inviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<Map<String, String?>> _namesFor(Iterable<String> userIds) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await _supabase
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', ids);
    return {
      for (final p in (rows as List).cast<Map<String, dynamic>>())
        p['id'] as String: p['display_name'] as String?,
    };
  }

  /// Lightweight cards for Home / list (no live, no tracks, no photos).
  Future<List<RodadaSummary>> listMyRodadas({int limit = 20}) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return const [];

    final memberRows = await _supabase
        .from('rodada_members')
        .select('rodada_id, rsvp')
        .eq('user_id', me)
        .order('joined_at', ascending: false)
        .limit(limit);

    final ids = <String>[];
    final rsvpById = <String, String>{};
    for (final r in (memberRows as List).cast<Map<String, dynamic>>()) {
      final id = r['rodada_id'] as String?;
      if (id == null) continue;
      ids.add(id);
      final rsvp = r['rsvp'] as String?;
      if (rsvp != null) rsvpById[id] = rsvp;
    }
    if (ids.isEmpty) return const [];

    final rows = await _supabase
        .from('rodadas')
        .select(
          '$rodadaSelectColumns, '
          'rodada_members(user_id)',
        )
        .inFilter('id', ids)
        .order('starts_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>().map((m) {
      final id = m['id'] as String?;
      return RodadaSummary.fromMap(
        m,
        myRsvp: id == null ? null : rsvpById[id],
      );
    }).toList();

      // Prefer live / upcoming first.
    list.sort((a, b) {
      int rank(RodadaSummary r) {
        switch (r.status) {
          case 'live':
            return 0;
          case 'open':
          case 'draft':
            return 1;
          default:
            return 2;
        }
      }

      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      final as = a.startsAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bs = b.startsAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bs.compareTo(as);
    });
    return list;
  }

  /// Live rodada first, then the most recent open one the rider belongs to.
  Future<RodadaSummary?> findAttachableRodada() async {
    final mine = await listMyRodadas(limit: 30);
    final attachable = mine
        .where((r) => r.status == 'live' || r.status == 'open')
        .toList();
    if (attachable.isEmpty) return null;
    attachable.sort(compareAttachableRodadas);
    return attachable.first;
  }

  Future<RodadaSummary?> getRodada(String id) async {
    await _ensure();
    final row = await _supabase
        .from('rodadas')
        .select(
          '$rodadaSelectColumns, '
          'rodada_members(user_id)',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return RodadaSummary.fromMap(Map<String, dynamic>.from(row));
  }

  Future<RodadaSummary> createRodada({
    required String title,
    String? destination,
    String? notes,
    double? meetupLat,
    double? meetupLng,
    double? finishLat,
    double? finishLng,
    DateTime? startsAt,
    DirectionsResult? route,
    RoutePrefs prefs = RoutePrefs.defaults,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');

    var code = _inviteCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final row = await _supabase
            .from('rodadas')
            .insert({
              'host_id': me,
              'title': title.trim(),
              'destination': destination?.trim(),
              'notes': notes?.trim(),
              'meetup_lat': meetupLat,
              'meetup_lng': meetupLng,
              'finish_lat': finishLat,
              'finish_lng': finishLng,
              'starts_at': startsAt?.toUtc().toIso8601String(),
              'status': 'open',
              'invite_code': code,
              'route_geometry': route?.encodedPolyline,
              'route_distance_m': route?.distanceM,
              'route_duration_s': route?.durationS,
              'route_prefs': prefs.toMap(),
              'route_provider': route?.provider,
            })
            .select(rodadaSelectColumns)
            .single();
        return RodadaSummary.fromMap(
          Map<String, dynamic>.from(row),
          memberCount: 1,
        );
      } catch (e) {
        debugPrint('createRodada code collision?: $e');
        code = _inviteCode();
      }
    }
    throw StateError('Could not create rodada');
  }

  Future<void> updateRodada(
    String id, {
    String? title,
    String? destination,
    String? notes,
    double? meetupLat,
    double? meetupLng,
    double? finishLat,
    double? finishLng,
    DateTime? startsAt,
    String? status,
    bool clearMeetup = false,
    bool clearFinish = false,
    DirectionsResult? route,
    RoutePrefs? routePrefs,
    bool clearRoute = false,
  }) async {
    await _ensure();
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null) patch['title'] = title.trim();
    if (destination != null) patch['destination'] = destination.trim();
    if (notes != null) patch['notes'] = notes.trim();
    if (clearMeetup) {
      patch['meetup_lat'] = null;
      patch['meetup_lng'] = null;
    } else {
      if (meetupLat != null) patch['meetup_lat'] = meetupLat;
      if (meetupLng != null) patch['meetup_lng'] = meetupLng;
    }
    if (clearFinish) {
      patch['finish_lat'] = null;
      patch['finish_lng'] = null;
    } else {
      if (finishLat != null) patch['finish_lat'] = finishLat;
      if (finishLng != null) patch['finish_lng'] = finishLng;
    }
    if (startsAt != null) {
      patch['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (status != null) patch['status'] = status;
    if (clearRoute) {
      patch['route_geometry'] = null;
      patch['route_distance_m'] = null;
      patch['route_duration_s'] = null;
      patch['route_provider'] = null;
    } else if (route != null) {
      patch['route_geometry'] = route.encodedPolyline;
      patch['route_distance_m'] = route.distanceM;
      patch['route_duration_s'] = route.durationS;
      patch['route_provider'] = route.provider;
    }
    if (routePrefs != null) patch['route_prefs'] = routePrefs.toMap();
    await _supabase.from('rodadas').update(patch).eq('id', id);
  }

  /// Recompute and store the road-follow line from current pins.
  Future<void> refreshStoredRoute(
    String rodadaId, {
    required DirectionsService directions,
  }) async {
    final rodada = await getRodada(rodadaId);
    if (rodada == null) return;
    final stops = await listStops(rodadaId);
    final pins = rodadaItineraryLine(
      start: rodada.hasMeetup
          ? LatLng(rodada.meetupLat!, rodada.meetupLng!)
          : null,
      stops: [for (final s in stops) LatLng(s.latitude, s.longitude)],
      finish: rodada.hasFinish
          ? LatLng(rodada.finishLat!, rodada.finishLng!)
          : null,
    );
    if (pins.length < 2) {
      await updateRodada(rodadaId, clearRoute: true, routePrefs: rodada.routePrefs);
      return;
    }
    final result = await directions.route(
      waypoints: pins,
      prefs: rodada.routePrefs,
    );
    if (result == null) {
      await updateRodada(rodadaId, clearRoute: true, routePrefs: rodada.routePrefs);
      return;
    }
    await updateRodada(
      rodadaId,
      route: result,
      routePrefs: rodada.routePrefs,
    );
  }

  Future<String> joinByCode(String code) async {
    await _ensure();
    final rid = await _supabase.rpc(
      'join_rodada_by_code',
      params: {'p_code': code.trim()},
    );
    return rid as String;
  }

  Future<RodadaInviteResult> inviteUser({
    required String rodadaId,
    required String userId,
  }) async {
    await _ensure();
    final existing = await _supabase
        .from('rodada_members')
        .select('rsvp, role')
        .eq('rodada_id', rodadaId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      final rsvp = existing['rsvp'] as String?;
      if (rsvp != null && rsvp != 'pending') {
        return const RodadaInviteResult(alreadyMember: true);
      }
    }
    await _supabase.from('rodada_members').upsert({
      'rodada_id': rodadaId,
      'user_id': userId,
      'role': 'rider',
      'rsvp': 'pending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    try {
      final res = await _supabase.functions.invoke(
        'notify-rodada-invite',
        body: {
          'rodada_id': rodadaId,
          'user_id': userId,
        },
      );
      PushDiagnostics.recordFunctionData('notify-rodada-invite', res.data);
      return RodadaInviteResult.fromFunctionData(res.data);
    } catch (e) {
      debugPrint('notify-rodada-invite: $e');
      PushDiagnostics.recordError('notify-rodada-invite', e);
      return RodadaInviteResult(error: _invitePushError(e));
    }
  }

  Future<List<RodadaMember>> listMembers(String rodadaId) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_members')
        .select(
          'rodada_id, user_id, role, rsvp, share_live, share_track, '
          'presence, joined_at',
        )
        .eq('rodada_id', rodadaId)
        .order('joined_at');
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _namesFor(list.map((r) => r['user_id'] as String));
    return list
        .map(
          (r) => RodadaMember.fromMap(
            r,
            displayName: names[r['user_id'] as String],
          ),
        )
        .toList();
  }

  Future<RodadaMember?> myMembership(String rodadaId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return null;
    final row = await _supabase
        .from('rodada_members')
        .select(
          'rodada_id, user_id, role, rsvp, share_live, share_track, '
          'presence, joined_at',
        )
        .eq('rodada_id', rodadaId)
        .eq('user_id', me)
        .maybeSingle();
    if (row == null) return null;
    return RodadaMember.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateMySharing({
    required String rodadaId,
    bool? shareLive,
    bool? shareTrack,
    String? rsvp,
    String? presence,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (shareLive != null) patch['share_live'] = shareLive;
    if (shareTrack != null) patch['share_track'] = shareTrack;
    if (rsvp != null) patch['rsvp'] = rsvp;
    if (presence != null) patch['presence'] = presence;
    await _supabase
        .from('rodada_members')
        .update(patch)
        .eq('rodada_id', rodadaId)
        .eq('user_id', me);

    if (shareLive == false) {
      await _supabase
          .from('rodada_live_positions')
          .delete()
          .eq('rodada_id', rodadaId)
          .eq('user_id', me);
    }
  }

  Future<void> leaveRodada(String rodadaId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _supabase
        .from('rodada_live_positions')
        .delete()
        .eq('rodada_id', rodadaId)
        .eq('user_id', me);
    await _supabase
        .from('rodada_members')
        .delete()
        .eq('rodada_id', rodadaId)
        .eq('user_id', me);
  }

  Future<List<RodadaLivePosition>> listLivePositions(String rodadaId) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_live_positions')
        .select(
          'rodada_id, user_id, latitude, longitude, speed_mps, heading, '
          'presence, updated_at',
        )
        .eq('rodada_id', rodadaId);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _namesFor(list.map((r) => r['user_id'] as String));
    // Keep last-known pins for the life of the rodada row (share-off deletes).
    // UI marks stale via [RodadaLivePosition.isStale] + last-signal time.
    return list
        .map(
          (r) => RodadaLivePosition.fromMap(
            r,
            displayName: names[r['user_id'] as String],
          ),
        )
        .toList();
  }

  Future<void> upsertLivePosition({
    required String rodadaId,
    required double latitude,
    required double longitude,
    double? speedMps,
    double? heading,
    String presence = 'riding',
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return;
    await _supabase.from('rodada_live_positions').upsert({
      'rodada_id': rodadaId,
      'user_id': me,
      'latitude': latitude,
      'longitude': longitude,
      'speed_mps': speedMps,
      'heading': heading,
      'presence': presence,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> clearMyLivePosition(String rodadaId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return;
    await _supabase
        .from('rodada_live_positions')
        .delete()
        .eq('rodada_id', rodadaId)
        .eq('user_id', me);
  }

  Future<List<RodadaRideSummary>> listRodadaRides(String rodadaId) async {
    await _ensure();
    final rows = await _supabase
        .from('rides')
        .select(
          'id, user_id, local_id, started_at, ended_at, distance_meters, '
          'point_count, max_speed_mps, line_score',
        )
        .eq('rodada_id', rodadaId)
        .order('started_at', ascending: false)
        .limit(40);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _namesFor(list.map((r) => r['user_id'] as String));
    return list
        .map(
          (r) => RodadaRideSummary.fromMap(
            r,
            displayName: names[r['user_id'] as String],
          ),
        )
        .toList();
  }

  /// Downsampled track for map overlay (releases when provider disposes).
  Future<List<({double lat, double lng})>> trackPointsDownsampled(
    String cloudRideId, {
    int maxPoints = 400,
  }) async {
    await _ensure();
    final list = await pagedSelect(
      client: _supabase,
      table: 'track_points',
      columns: 'latitude, longitude, recorded_at',
      eqColumn: 'ride_id',
      eqValue: cloudRideId,
      orderBy: 'recorded_at',
    );
    if (list.isEmpty) return const [];
    if (list.length <= maxPoints) {
      return [
        for (final r in list)
          (
            lat: (r['latitude'] as num).toDouble(),
            lng: (r['longitude'] as num).toDouble(),
          ),
      ];
    }
    final step = list.length / maxPoints;
    final out = <({double lat, double lng})>[];
    for (var i = 0; i < maxPoints; i++) {
      final r = list[(i * step).floor().clamp(0, list.length - 1)];
      out.add((
        lat: (r['latitude'] as num).toDouble(),
        lng: (r['longitude'] as num).toDouble(),
      ));
    }
    return out;
  }

  Future<String?> cloudRideIdForLocal(String localId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return null;
    final row = await _supabase
        .from('rides')
        .select('id')
        .eq('user_id', me)
        .eq('local_id', localId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  Future<String?> linkedRodadaIdForLocal(String localId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return null;
    final row = await _supabase
        .from('rides')
        .select('rodada_id')
        .eq('user_id', me)
        .eq('local_id', localId)
        .maybeSingle();
    final id = row?['rodada_id'] as String?;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> linkRideToRodada({
    required String cloudRideId,
    required String rodadaId,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _supabase
        .from('rides')
        .update({
          'rodada_id': rodadaId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', cloudRideId)
        .eq('user_id', me);
    await updateMySharing(rodadaId: rodadaId, shareTrack: true);
  }

  Future<void> unlinkRide(String cloudRideId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return;
    await _supabase
        .from('rides')
        .update({
          'rodada_id': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', cloudRideId)
        .eq('user_id', me);
  }

  Future<List<RodadaPhoto>> listPhotos(
    String rodadaId, {
    int limit = 24,
    int offset = 0,
  }) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_photos')
        .select(
          'id, rodada_id, user_id, storage_path, caption, latitude, '
          'longitude, created_at, taken_at, ride_id, source, content_hash',
        )
        .eq('rodada_id', rodadaId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _namesFor(list.map((r) => r['user_id'] as String));
    return list
        .map(
          (r) => RodadaPhoto.fromMap(
            r,
            displayName: names[r['user_id'] as String],
          ),
        )
        .toList();
  }

  Future<String> signedPhotoUrl(String storagePath) async {
    await _ensure();
    final res = await _supabase.storage
        .from('rodada-photos')
        .createSignedUrl(storagePath, 3600);
    return res;
  }

  Future<RodadaPhoto> uploadPhoto({
    required String rodadaId,
    required Uint8List bytes,
    required String contentType,
    String? caption,
    double? latitude,
    double? longitude,
    DateTime? takenAt,
    String? rideId,
    String? source,
    String? contentHash,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _assertNotBanned(me);
    final hash = contentHash ?? sha256.convert(bytes).toString();
    final existing = await _supabase
        .from('rodada_photos')
        .select('id')
        .eq('rodada_id', rodadaId)
        .eq('user_id', me)
        .eq('content_hash', hash)
        .maybeSingle();
    if (existing != null) {
      final row = await _supabase
          .from('rodada_photos')
          .select()
          .eq('id', existing['id'] as String)
          .single();
      return RodadaPhoto.fromMap(Map<String, dynamic>.from(row));
    }
    final ext = contentType.contains('png')
        ? 'png'
        : contentType.contains('webp')
            ? 'webp'
            : 'jpg';
    final path =
        '$rodadaId/$me/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _supabase.storage.from('rodada-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final row = await _supabase
        .from('rodada_photos')
        .insert({
          'rodada_id': rodadaId,
          'user_id': me,
          'storage_path': path,
          'caption': caption,
          'latitude': latitude,
          'longitude': longitude,
          'taken_at': takenAt?.toUtc().toIso8601String(),
          'ride_id': rideId,
          'source': source,
          'content_hash': hash,
        })
        .select()
        .single();
    return RodadaPhoto.fromMap(Map<String, dynamic>.from(row));
  }

  Future<String> signedReelUrl(String storagePath) async {
    await _ensure();
    return _supabase.storage
        .from('rodada-reels')
        .createSignedUrl(storagePath, 3600);
  }

  Future<void> uploadReel({
    required String rodadaId,
    required String localPath,
    required int durationMs,
    required String hookKind,
    String? rideId,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _assertNotBanned(me);
    final path =
        '$rodadaId/$me/${DateTime.now().millisecondsSinceEpoch}.mp4';
    await _supabase.storage.from('rodada-reels').upload(
          path,
          File(localPath),
          fileOptions: const FileOptions(contentType: 'video/mp4', upsert: false),
        );
    await _supabase.from('rodada_reels').insert({
      'rodada_id': rodadaId,
      'ride_id': rideId,
      'user_id': me,
      'storage_path': path,
      'duration_ms': durationMs,
      'hook_kind': hookKind,
    });
  }

  Future<List<RodadaMessage>> listMessages(
    String rodadaId, {
    int limit = 50,
  }) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_messages')
        .select('id, rodada_id, user_id, body, kind, created_at')
        .eq('rodada_id', rodadaId)
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (rows as List).cast<Map<String, dynamic>>();
    final names = await _namesFor(list.map((r) => r['user_id'] as String));
    return list
        .map(
          (r) => RodadaMessage.fromMap(
            r,
            displayName: names[r['user_id'] as String],
          ),
        )
        .toList()
        .reversed
        .toList();
  }

  Future<RodadaMessage> sendMessage({
    required String rodadaId,
    required String body,
    String kind = 'text',
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    await _assertNotBanned(me);
    final row = await _supabase
        .from('rodada_messages')
        .insert({
          'rodada_id': rodadaId,
          'user_id': me,
          'body': body.trim(),
          'kind': kind,
        })
        .select()
        .single();
    final msg = RodadaMessage.fromMap(Map<String, dynamic>.from(row));
    try {
      final res = await _supabase.functions.invoke(
        'notify-rodada-radio',
        body: {
          'rodada_id': rodadaId,
          'message_id': msg.id,
        },
      );
      PushDiagnostics.recordFunctionData('notify-rodada-radio', res.data);
    } catch (e) {
      debugPrint('notify-rodada-radio: $e');
      PushDiagnostics.recordError('notify-rodada-radio', e);
    }
    return msg;
  }

  Future<List<RodadaStop>> listStops(String rodadaId) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_stops')
        .select()
        .eq('rodada_id', rodadaId)
        .order('sort_order')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RodadaStop.fromMap)
        .toList();
  }

  Future<int> _nextStopSortOrder(String rodadaId) async {
    final rows = await _supabase
        .from('rodada_stops')
        .select('sort_order')
        .eq('rodada_id', rodadaId)
        .order('sort_order', ascending: false)
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    return nextStopSortOrder([
      for (final r in list) (r['sort_order'] as num?)?.toInt() ?? 0,
    ]);
  }

  Future<RodadaStop> addStop({
    required String rodadaId,
    required String title,
    required double latitude,
    required double longitude,
    int? sortOrder,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    final order = sortOrder ?? await _nextStopSortOrder(rodadaId);
    final row = await _supabase
        .from('rodada_stops')
        .insert({
          'rodada_id': rodadaId,
          'created_by': me,
          'title': title.trim(),
          'latitude': latitude,
          'longitude': longitude,
          'sort_order': order,
        })
        .select()
        .single();
    return RodadaStop.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteStop(String stopId) async {
    await _ensure();
    await _supabase.from('rodada_stops').delete().eq('id', stopId);
  }

  Future<void> _assertNotBanned(String userId) async {
    final row = await _supabase
        .from('user_bans')
        .select('user_id')
        .eq('user_id', userId)
        .maybeSingle();
    if (row != null) {
      throw StateError('ugc_banned');
    }
  }
}
