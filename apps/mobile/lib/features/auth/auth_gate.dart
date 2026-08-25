import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../features/home/home_screen.dart';
import '../../features/legal/legal_acceptance.dart';
import '../../features/legal/terms_accept_screen.dart';
import '../../providers/auth_providers.dart';
import 'set_password_screen.dart';
import 'sign_in_screen.dart';

/// Blocks the app until the rider has a Google or email account.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (SupabaseBootstrap.isReady) {
      _authSub = SupabaseBootstrap.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          ref.read(passwordRecoveryActiveProvider.notifier).state = true;
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(passwordRecoveryActiveProvider)) {
      return const SetPasswordScreen();
    }
    if (!ref.watch(hasPermanentIdentityProvider)) {
      return const SignInScreen();
    }
    final terms = ref.watch(termsAcceptedProvider);
    return terms.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const TermsAcceptScreen(),
      data: (accepted) =>
          accepted ? const HomeScreen() : const TermsAcceptScreen(),
    );
  }
}
