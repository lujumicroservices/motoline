import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_provider_kind.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/impersonation_controller.dart';
import '../core/supabase/supabase_bootstrap.dart';
import 'alias_provider.dart';
import 'ride_providers.dart';
import 'social_providers.dart';
import 'supabase_providers.dart';
import 'pro_entitlement_provider.dart';

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

/// True while a password-recovery deep link session is active.
final passwordRecoveryActiveProvider = StateProvider<bool>((ref) => false);

/// Controllers for sign-in / sign-out with shared busy + error state.
class AuthActions {
  AuthActions(this.ref);

  final Ref ref;

  AuthService get _auth => ref.read(authServiceProvider);

  Future<bool> signIn(AuthProviderKind provider) {
    return _complete(() => _auth.signInWith(provider));
  }

  Future<bool> signInWithEmail(String email, String password) {
    return _complete(
      () => _auth.signInWithEmail(email: email, password: password),
    );
  }

  Future<bool> signUpWithEmail(String email, String password) {
    return _complete(
      () => _auth.signUpWithEmail(email: email, password: password),
    );
  }

  Future<bool> requestPasswordReset(String email) async {
    ref.read(authBusyProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      await _auth.requestPasswordReset(email);
      return true;
    } on AuthException catch (e) {
      ref.read(authErrorProvider.notifier).state = e.message;
      return false;
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = '$e';
      return false;
    } finally {
      ref.read(authBusyProvider.notifier).state = false;
    }
  }

  Future<void> updatePassword(String password) async {
    await _auth.updatePassword(password);
  }

  Future<bool> _complete(Future<void> Function() action) async {
    ref.read(authBusyProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      await action();
      await ref.read(impersonationProvider.notifier).refreshStaff();
      final label = await _auth.syncLinkedProfile(force: true) ??
          _auth.displayLabel;
      if (label != null && label.isNotEmpty) {
        await ref.read(riderAliasProvider.notifier).setAlias(label);
      }
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
      // Show local garage immediately; metadata pull runs in the background.
      ref.invalidate(ridesListProvider);
      unawaited(
        ref.read(garageCloudSyncProvider.notifier).ensureStarted(force: true),
      );
      unawaited(ref.read(proEntitlementProvider.notifier).refresh());
      return true;
    } on AuthException catch (e) {
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
      final imp = ref.read(impersonationProvider);
      if (imp.active) {
        await ref.read(impersonationProvider.notifier).exit();
        return;
      }
      await _auth.signOut();
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
      unawaited(ref.read(proEntitlementProvider.notifier).onSignedOut());
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = '$e';
    } finally {
      ref.read(authBusyProvider.notifier).state = false;
    }
  }

  /// Permanently deletes the cloud account + local garage. Irreversible.
  Future<bool> deleteAccount() async {
    ref.read(authBusyProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      final imp = ref.read(impersonationProvider);
      if (imp.active) {
        await ref.read(impersonationProvider.notifier).exit();
      }
      await _auth.deleteAccount();
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
      ref.invalidate(ridesListProvider);
      unawaited(ref.read(proEntitlementProvider.notifier).onSignedOut());
      return true;
    } on AuthException catch (e) {
      ref.read(authErrorProvider.notifier).state = e.message;
      return false;
    } catch (e) {
      ref.read(authErrorProvider.notifier).state = '$e';
      return false;
    } finally {
      ref.read(authBusyProvider.notifier).state = false;
    }
  }
}

final authActionsProvider = Provider<AuthActions>((ref) => AuthActions(ref));
