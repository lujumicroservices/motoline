import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/push_notification_service.dart';
import '../supabase/supabase_bootstrap.dart';
import '../../providers/alias_provider.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../features/rodadas/rodada_providers.dart';
import 'impersonation_store.dart';

class ImpersonationHit {
  const ImpersonationHit({
    required this.id,
    this.displayName,
    this.email,
  });

  final String id;
  final String? displayName;
  final String? email;

  String get label {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = email?.trim();
    if (e != null && e.isNotEmpty) return e;
    if (id.length >= 8) return id.substring(0, 8);
    return id;
  }
}

class ImpersonationState {
  const ImpersonationState({
    this.active = false,
    this.targetId,
    this.targetLabel,
    this.staff = false,
    this.busy = false,
    this.error,
  });

  final bool active;
  final String? targetId;
  final String? targetLabel;
  final bool staff;
  final bool busy;
  final String? error;

  ImpersonationState copyWith({
    bool? active,
    String? targetId,
    String? targetLabel,
    bool? staff,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearTarget = false,
  }) {
    return ImpersonationState(
      active: active ?? this.active,
      targetId: clearTarget ? null : (targetId ?? this.targetId),
      targetLabel: clearTarget ? null : (targetLabel ?? this.targetLabel),
      staff: staff ?? this.staff,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ImpersonationController extends StateNotifier<ImpersonationState> {
  ImpersonationController(this._ref) : super(const ImpersonationState()) {
    Future.microtask(_hydrate);
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    await ImpersonationStore.hydrate();
    var staff = false;
    if (SupabaseBootstrap.isReady && !ImpersonationStore.isActive) {
      staff = await _probeStaff();
    }
    state = ImpersonationState(
      active: ImpersonationStore.isActive,
      targetId: ImpersonationStore.targetId,
      targetLabel: ImpersonationStore.targetLabel,
      staff: staff || ImpersonationStore.isActive,
    );
  }

  Future<bool> _probeStaff() async {
    try {
      final uid = SupabaseBootstrap.client.auth.currentUser?.id;
      if (uid == null) return false;
      final row = await SupabaseBootstrap.client
          .from('staff_admins')
          .select('user_id')
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('staff_admins probe: $e');
      return false;
    }
  }

  Future<void> refreshStaff() async {
    if (state.active) return;
    final staff = await _probeStaff();
    state = state.copyWith(staff: staff);
  }

  Future<List<ImpersonationHit>> search(String query) async {
    if (!SupabaseBootstrap.isReady) return const [];
    final res = await SupabaseBootstrap.client.functions.invoke(
      'impersonate-user',
      body: {'action': 'search', 'q': query.trim()},
    );
    final data = res.data;
    if (data is! Map) return const [];
    if (data['error'] != null) {
      throw StateError('${data['error']}');
    }
    final raw = data['riders'];
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map)
          ImpersonationHit(
            id: '${row['id']}',
            displayName: row['display_name'] as String?,
            email: row['email'] as String?,
          ),
    ];
  }

  Future<bool> start({
    required String userId,
    required String label,
  }) async {
    if (!SupabaseBootstrap.isReady) return false;
    final auth = SupabaseBootstrap.client.auth;
    final session = auth.currentSession;
    final access = session?.accessToken;
    final refresh = session?.refreshToken;
    if (session == null ||
        access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      state = state.copyWith(error: 'No staff session to restore later.');
      return false;
    }

    state = state.copyWith(busy: true, clearError: true);
    try {
      final res = await SupabaseBootstrap.client.functions.invoke(
        'impersonate-user',
        body: {'action': 'start', 'user_id': userId},
      );
      final data = res.data;
      if (data is! Map || data['hashed_token'] is! String) {
        final err = data is Map ? data['error'] : res.status;
        throw StateError('${err ?? 'impersonate_failed'}');
      }
      final hash = data['hashed_token'] as String;
      final target = data['target'];
      final targetLabel = target is Map
          ? (target['display_name'] as String? ?? label)
          : label;

      await ImpersonationStore.persistActive(
        adminAccessToken: access,
        adminRefreshToken: refresh,
        targetId: userId,
        targetLabel: targetLabel,
      );

      try {
        await auth.verifyOTP(
          tokenHash: hash,
          type: OtpType.email,
        );
      } on AuthException {
        await auth.verifyOTP(
          tokenHash: hash,
          type: OtpType.magiclink,
        );
      }

      state = ImpersonationState(
        active: true,
        targetId: userId,
        targetLabel: targetLabel,
        staff: true,
      );
      _invalidateCloud();
      return true;
    } catch (e) {
      await ImpersonationStore.clear();
      state = state.copyWith(busy: false, error: '$e', active: false);
      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  Future<bool> exit() async {
    if (!state.active && !ImpersonationStore.isActive) return true;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final tokens = await ImpersonationStore.savedAdminTokens();
      if (tokens == null) {
        throw StateError('Missing staff session. Sign in with Google.');
      }
      if (SupabaseBootstrap.isReady) {
        await SupabaseBootstrap.client.auth.setSession(tokens.refresh);
      }
      await ImpersonationStore.clear();
      try {
        await PushNotificationService.instance.syncToken();
      } catch (e) {
        debugPrint('FCM after impersonation exit: $e');
      }
      state = const ImpersonationState(staff: true);
      _invalidateCloud();
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: '$e');
      return false;
    } finally {
      if (mounted) {
        state = state.copyWith(busy: false);
      }
    }
  }

  void _invalidateCloud() {
    _ref.invalidate(myProfileProvider);
    _ref.invalidate(friendsListProvider);
    _ref.invalidate(myRodadasProvider);
    _ref.invalidate(ridesListProvider);
    _ref.invalidate(riderAliasProvider);
  }
}

final impersonationProvider =
    StateNotifierProvider<ImpersonationController, ImpersonationState>((ref) {
  return ImpersonationController(ref);
});
