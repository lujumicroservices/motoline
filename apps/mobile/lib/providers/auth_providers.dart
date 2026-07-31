import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_provider_kind.dart';
import '../core/auth/auth_service.dart';
import '../core/supabase/supabase_bootstrap.dart';
import 'alias_provider.dart';
import 'social_providers.dart';
import 'supabase_providers.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Live auth user (null if signed out / cloud offline).
final authUserProvider = Provider<User?>((ref) {
  ref.watch(supabaseSessionProvider);
  if (!SupabaseBootstrap.isReady) return null;
  return SupabaseBootstrap.client.auth.currentUser;
});

final isAnonymousAuthProvider = Provider<bool>((ref) {
  final user = ref.watch(authUserProvider);
  return user == null || user.isAnonymous;
});

final hasPermanentIdentityProvider = Provider<bool>((ref) {
  final auth = ref.watch(authServiceProvider);
  ref.watch(supabaseSessionProvider);
  return auth.hasPermanentIdentity;
});

final authBusyProvider = StateProvider<bool>((ref) => false);

final authErrorProvider = StateProvider<String?>((ref) => null);

/// Controllers for sign-in / sign-out with shared busy + error state.
class AuthActions {
  AuthActions(this.ref);

  final Ref ref;

  AuthService get _auth => ref.read(authServiceProvider);

  Future<bool> signIn(AuthProviderKind provider) async {
    ref.read(authBusyProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      await _auth.signInWith(provider);
      final label = _auth.displayLabel;
      if (label != null && label.isNotEmpty) {
        await ref.read(riderAliasProvider.notifier).setAlias(label);
      }
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
      return true;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('cancel')) {
        ref.read(authErrorProvider.notifier).state = null;
        return false;
      }
      ref.read(authErrorProvider.notifier).state = e.message;
      return false;
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = '$e';
      return false;
    } finally {
      ref.read(authBusyProvider.notifier).state = false;
    }
  }

  Future<void> signOut() async {
    ref.read(authBusyProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      await _auth.signOut();
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(authBusyProvider.notifier).state = false;
    }
  }
}

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));
