import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import 'watch_models.dart';
import 'watch_token_store.dart';

class WatchRepository {
  WatchRepository({WatchTokenStore? tokenStore})
      : _tokens = tokenStore ?? WatchTokenStore();

  final WatchTokenStore _tokens;

  SupabaseClient get _db => SupabaseBootstrap.client;

  String? get _uid => _db.auth.currentUser?.id;

  /// Public watch page base, e.g. https://host/watch/
  static String get shareBaseUrl {
    final fromEnv = dotenv.env['WATCH_SHARE_BASE_URL']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv.endsWith('/') ? fromEnv : '$fromEnv/';
    }
    return 'https://riderlabdeck.z21.web.core.windows.net/watch/';
  }

  static String shareUrlForToken(String token) => '$shareBaseUrl?t=$token';

  /// Stable key for rodada-scoped watch sessions (no solo ride required).
  static String rodadaLocalRideId(String rodadaId) => 'rodada:$rodadaId';

  Future<List<TrustedContact>> listMyContacts() async {
    final me = _uid;
    if (me == null) return const [];
    final rows = await _db
        .from('trusted_contacts')
        .select()
        .eq('owner_id', me)
        .neq('status', 'revoked')
        .order('created_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(TrustedContact.fromMap)
        .toList();
  }

  Future<TrustedContact> addLabelContact(String label) async {
    final me = _uid;
    if (me == null) throw StateError('Not signed in');
    final row = await _db
        .from('trusted_contacts')
        .insert({
          'owner_id': me,
          'display_label': label.trim().isEmpty ? 'Family' : label.trim(),
          'status': 'active',
        })
        .select()
        .single();
    return TrustedContact.fromMap(row);
  }

  Future<TrustedContact> addFriendContact({
    required String friendUserId,
    required String label,
  }) async {
    final me = _uid;
    if (me == null) throw StateError('Not signed in');
    final row = await _db
        .from('trusted_contacts')
        .insert({
          'owner_id': me,
          'contact_user_id': friendUserId,
          'display_label': label.trim().isEmpty ? 'Family' : label.trim(),
          'status': 'active',
        })
        .select()
        .single();
    return TrustedContact.fromMap(row);
  }

  Future<void> revokeContact(String id) async {
    await _db.from('trusted_contacts').update({
      'status': 'revoked',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<WatchSession> startSession({
    required String localRideId,
    String? riderDisplayName,
  }) async {
    final me = _uid;
    if (me == null) throw StateError('Not signed in');

    // End any prior active session for this rider.
    await _db
        .from('watch_sessions')
        .update({
          'status': 'ended',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('rider_id', me)
        .eq('status', 'active');

    final row = await _db
        .from('watch_sessions')
        .insert({
          'rider_id': me,
          'local_ride_id': localRideId,
          'status': 'active',
          'rider_display_name': riderDisplayName,
        })
        .select()
        .single();

    final session = WatchSession.fromMap(row);
    await _db.from('watch_events').insert({
      'session_id': session.id,
      'kind': 'started',
    });

    final token = await createShareToken(session.id, revokeExisting: false);
    return WatchSession.fromMap(row, shareUrl: shareUrlForToken(token));
  }

  /// Returns the same live URL for everyone. Does **not** revoke prior shares.
  Future<String> ensureShareUrl(String sessionId) async {
    final cached = await _tokens.load(sessionId);
    if (cached != null && cached.length >= 16) {
      return shareUrlForToken(cached);
    }
    final raw = await createShareToken(sessionId, revokeExisting: false);
    return shareUrlForToken(raw);
  }

  /// Creates a token. When [revokeExisting] is true, old links stop working.
  Future<String> createShareToken(
    String sessionId, {
    bool revokeExisting = false,
  }) async {
    final me = _uid;
    if (me == null) throw StateError('Not signed in');

    if (revokeExisting) {
      await _db
          .from('watch_share_tokens')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('session_id', sessionId)
          .filter('revoked_at', 'is', null);
    }

    final raw = _randomToken();
    final hash = sha256Hex(raw);
    final expires = DateTime.now().toUtc().add(const Duration(hours: 12));
    await _db.from('watch_share_tokens').insert({
      'session_id': sessionId,
      'token_hash': hash,
      'expires_at': expires.toIso8601String(),
    });
    await _tokens.save(sessionId, raw);
    return raw;
  }

  /// Invalidates every prior magic link and issues a fresh one.
  Future<WatchSession> rotateShareLink(String sessionId) async {
    final row = await _db
        .from('watch_sessions')
        .select()
        .eq('id', sessionId)
        .single();
    final token = await createShareToken(sessionId, revokeExisting: true);
    return WatchSession.fromMap(row, shareUrl: shareUrlForToken(token));
  }

  Future<void> upsertPosition({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? speedMps,
    double? heading,
  }) async {
    await _db.from('watch_positions').upsert({
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_mps': speedMps,
      'heading': heading,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> postEvent(String sessionId, String kind, {String? note}) async {
    await _db.from('watch_events').insert({
      'session_id': sessionId,
      'kind': kind,
      'note': note,
    });
  }

  Future<void> endSession(String sessionId, {bool cancelled = false}) async {
    final status = cancelled ? 'cancelled' : 'ended';
    await _db.from('watch_sessions').update({
      'status': status,
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
    await postEvent(sessionId, status);
    await _db
        .from('watch_share_tokens')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('session_id', sessionId)
        .filter('revoked_at', 'is', null);
    await _tokens.clear(sessionId);
  }

  Future<WatchSession?> activeSessionForRide(String localRideId) async {
    final me = _uid;
    if (me == null) return null;
    final rows = await _db
        .from('watch_sessions')
        .select()
        .eq('rider_id', me)
        .eq('local_ride_id', localRideId)
        .eq('status', 'active')
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return attachShareUrl(
      WatchSession.fromMap(list.first as Map<String, dynamic>),
    );
  }

  Future<WatchSession?> activeSessionMine() async {
    final me = _uid;
    if (me == null) return null;
    final rows = await _db
        .from('watch_sessions')
        .select()
        .eq('rider_id', me)
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return attachShareUrl(
      WatchSession.fromMap(list.first as Map<String, dynamic>),
    );
  }

  Future<WatchSession> attachShareUrl(WatchSession session) async {
    if (session.shareUrl != null) return session;
    final url = await ensureShareUrl(session.id);
    return WatchSession(
      id: session.id,
      riderId: session.riderId,
      localRideId: session.localRideId,
      cloudRideId: session.cloudRideId,
      status: session.status,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      riderDisplayName: session.riderDisplayName,
      shareUrl: url,
    );
  }

  /// Sessions of friends who added me to their circle (in-app viewer).
  Future<List<WatchSession>> listVisibleActiveSessions() async {
    final me = _uid;
    if (me == null) return const [];
    final rows = await _db
        .from('watch_sessions')
        .select()
        .eq('status', 'active')
        .order('started_at', ascending: false)
        .limit(20);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WatchSession.fromMap)
        .toList();
  }

  Future<WatchPosition?> getPosition(String sessionId) async {
    final rows = await _db
        .from('watch_positions')
        .select()
        .eq('session_id', sessionId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return WatchPosition.fromMap(list.first as Map<String, dynamic>);
  }

  Future<List<WatchEvent>> listEvents(String sessionId) async {
    final rows = await _db
        .from('watch_events')
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(WatchEvent.fromMap)
        .toList();
  }

  String _randomToken() {
    final r = Random.secure();
    final bytes = List<int>.generate(24, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
