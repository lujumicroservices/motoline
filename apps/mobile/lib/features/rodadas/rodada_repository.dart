import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'models/rodada_models.dart';

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

  String? get currentUserId => _supabase.auth.currentUser?.id;

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
        .select('rodada_id')
        .eq('user_id', me)
        .order('joined_at', ascending: false)
        .limit(limit);

    final ids = (memberRows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['rodada_id'] as String)
        .toList();
    if (ids.isEmpty) return const [];

    final rows = await _supabase
        .from('rodadas')
        .select(
          'id, host_id, title, destination, notes, meetup_lat, meetup_lng, '
          'starts_at, status, invite_code, created_at, updated_at, '
          'rodada_members(user_id)',
        )
        .inFilter('id', ids)
        .order('starts_at', ascending: false);

    final list = (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RodadaSummary.fromMap)
        .toList();

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

  Future<RodadaSummary?> getRodada(String id) async {
    await _ensure();
    final row = await _supabase
        .from('rodadas')
        .select(
          'id, host_id, title, destination, notes, meetup_lat, meetup_lng, '
          'starts_at, status, invite_code, created_at, updated_at, '
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
    DateTime? startsAt,
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
              'starts_at': startsAt?.toUtc().toIso8601String(),
              'status': 'open',
              'invite_code': code,
            })
            .select(
              'id, host_id, title, destination, notes, meetup_lat, meetup_lng, '
              'starts_at, status, invite_code, created_at, updated_at',
            )
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
    DateTime? startsAt,
    String? status,
    bool clearMeetup = false,
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
    if (startsAt != null) {
      patch['starts_at'] = startsAt.toUtc().toIso8601String();
    }
    if (status != null) patch['status'] = status;
    await _supabase.from('rodadas').update(patch).eq('id', id);
  }

  Future<String> joinByCode(String code) async {
    await _ensure();
    final rid = await _supabase.rpc(
      'join_rodada_by_code',
      params: {'p_code': code.trim()},
    );
    return rid as String;
  }

  Future<void> inviteUser({
    required String rodadaId,
    required String userId,
  }) async {
    await _ensure();
    await _supabase.from('rodada_members').upsert({
      'rodada_id': rodadaId,
      'user_id': userId,
      'role': 'rider',
      'rsvp': 'pending',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
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
    final rows = await _supabase
        .from('track_points')
        .select('latitude, longitude')
        .eq('ride_id', cloudRideId)
        .order('recorded_at');
    final list = (rows as List).cast<Map<String, dynamic>>();
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
          'longitude, created_at',
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
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
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
        })
        .select()
        .single();
    return RodadaPhoto.fromMap(Map<String, dynamic>.from(row));
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
    return RodadaMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<RodadaStop>> listStops(String rodadaId) async {
    await _ensure();
    final rows = await _supabase
        .from('rodada_stops')
        .select()
        .eq('rodada_id', rodadaId)
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RodadaStop.fromMap)
        .toList();
  }

  Future<RodadaStop> addStop({
    required String rodadaId,
    required String title,
    required double latitude,
    required double longitude,
  }) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    final row = await _supabase
        .from('rodada_stops')
        .insert({
          'rodada_id': rodadaId,
          'created_by': me,
          'title': title.trim(),
          'latitude': latitude,
          'longitude': longitude,
        })
        .select()
        .single();
    return RodadaStop.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteStop(String stopId) async {
    await _ensure();
    await _supabase.from('rodada_stops').delete().eq('id', stopId);
  }
}
