import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cloud_models.dart';
import '../supabase/supabase_bootstrap.dart';

enum FriendshipStatus { pending, accepted, declined }

class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    this.peer,
    this.createdAt,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final RiderProfile? peer;
  final DateTime? createdAt;

  bool isIncoming(String me) => addresseeId == me && status == FriendshipStatus.pending;
  bool isOutgoing(String me) => requesterId == me && status == FriendshipStatus.pending;
}

/// Friend requests + accepted friends (replaces “all profiles” list).
class FriendshipRepository {
  FriendshipRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

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

  FriendshipStatus _status(String? raw) {
    switch (raw) {
      case 'accepted':
        return FriendshipStatus.accepted;
      case 'declined':
        return FriendshipStatus.declined;
      default:
        return FriendshipStatus.pending;
    }
  }

  Future<Map<String, String?>> _names(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _supabase
        .from('profiles')
        .select('id, display_name')
        .inFilter('id', list);
    return {
      for (final p in (rows as List).cast<Map<String, dynamic>>())
        p['id'] as String: p['display_name'] as String?,
    };
  }

  Future<List<Friendship>> _mapRows(List<Map<String, dynamic>> rows) async {
    final me = currentUserId;
    final peerIds = <String>[];
    for (final r in rows) {
      final req = r['requester_id'] as String;
      final add = r['addressee_id'] as String;
      if (me != null) {
        peerIds.add(req == me ? add : req);
      }
    }
    final names = await _names(peerIds);
    return [
      for (final r in rows)
        Friendship(
          id: r['id'] as String,
          requesterId: r['requester_id'] as String,
          addresseeId: r['addressee_id'] as String,
          status: _status(r['status'] as String?),
          createdAt: r['created_at'] == null
              ? null
              : DateTime.tryParse(r['created_at'] as String),
          peer: () {
            if (me == null) return null;
            final peerId = r['requester_id'] == me
                ? r['addressee_id'] as String
                : r['requester_id'] as String;
            return RiderProfile(
              id: peerId,
              displayName: names[peerId],
            );
          }(),
        ),
    ];
  }

  Future<List<RiderProfile>> listAcceptedFriends() async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return const [];
    final rows = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('status', 'accepted')
        .or('requester_id.eq.$me,addressee_id.eq.$me');
    final friendships =
        await _mapRows((rows as List).cast<Map<String, dynamic>>());
    return [
      for (final f in friendships)
        if (f.peer != null) f.peer!,
    ];
  }

  Future<List<Friendship>> listIncomingRequests() async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return const [];
    final rows = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('addressee_id', me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return _mapRows((rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Friendship>> listOutgoingRequests() async {
    await _ensure();
    final me = currentUserId;
    if (me == null) return const [];
    final rows = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('requester_id', me)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return _mapRows((rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<RiderProfile>> searchRiders(String query) async {
    await _ensure();
    final q = query.trim();
    if (q.length < 2) return const [];
    final rows = await _supabase.rpc(
      'search_riders',
      params: {'p_query': q, 'p_limit': 20},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(RiderProfile.fromMap)
        .toList();
  }

  Future<void> requestFriend(String userId) async {
    await _ensure();
    final me = currentUserId;
    if (me == null) throw StateError('Not signed in');
    if (userId == me) throw StateError('Cannot friend yourself');

    final existing = await _supabase
        .from('friendships')
        .select('id, requester_id, addressee_id, status')
        .or(
          'and(requester_id.eq.$me,addressee_id.eq.$userId),'
          'and(requester_id.eq.$userId,addressee_id.eq.$me)',
        )
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String?;
      if (status == 'accepted') return;
      if (status == 'pending') {
        // Already pending either direction.
        return;
      }
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', existing['id'] as String);
    }

    await _supabase.from('friendships').insert({
      'requester_id': me,
      'addressee_id': userId,
      'status': 'pending',
    });
  }

  Future<void> acceptRequest(String friendshipId) async {
    await _ensure();
    await _supabase.from('friendships').update({
      'status': 'accepted',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', friendshipId);
  }

  Future<void> declineRequest(String friendshipId) async {
    await _ensure();
    await _supabase.from('friendships').update({
      'status': 'declined',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', friendshipId);
  }

  Future<void> removeFriendship(String friendshipId) async {
    await _ensure();
    await _supabase.from('friendships').delete().eq('id', friendshipId);
  }

  Future<void> cancelOutgoing(String friendshipId) =>
      removeFriendship(friendshipId);
}
