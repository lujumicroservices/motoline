import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/home_screen.dart';
import '../../providers/auth_providers.dart';
import 'sign_in_screen.dart';

/// Blocks the app until the rider has a Google or email account.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasPermanentIdentityProvider)) {
      return const SignInScreen();
    }
    return const HomeScreen();
  }
}
