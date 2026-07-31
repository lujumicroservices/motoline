import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';
import 'auth_provider_kind.dart';

/// Tokens obtained from a native OAuth SDK (Google today; Apple later).
class NativeIdTokens {
  const NativeIdTokens({
    required this.idToken,
    this.accessToken,
  });

  final String idToken;
  final String? accessToken;
}

/// Extensible auth facade over Supabase.
///
/// - Soft guest: [SupabaseBootstrap.ensureSession] (anonymous)
/// - Permanent: [signInWith] — links Google onto the anonymous user when possible
///   so rides / profile `id` stay the same
class AuthService {
  AuthService();

  bool _googleReady = false;

  User? get currentUser =>
      SupabaseBootstrap.isReady ? SupabaseBootstrap.client.auth.currentUser : null;

  Session? get currentSession => SupabaseBootstrap.isReady
      ? SupabaseBootstrap.client.auth.currentSession
      : null;

  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  bool get hasPermanentIdentity {
    final user = currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.identities?.any((i) => i.provider != 'anonymous') ??
        (user.email != null && user.email!.isNotEmpty);
  }

  String? get displayLabel {
    final user = currentUser;
    if (user == null) return null;
    final meta = user.userMetadata;
    final name = meta?['full_name'] as String? ??
        meta?['name'] as String? ??
        meta?['user_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  /// Providers the app can offer in Settings (filter by platform later).
  List<AuthProviderKind> get availableProviders => const [
        AuthProviderKind.google,
      ];

  Future<AuthResponse> signInWith(AuthProviderKind provider) async {
    return switch (provider) {
      AuthProviderKind.google => _signInWithGoogle(),
    };
  }

  Future<AuthResponse> _signInWithGoogle() async {
    final tokens = await _obtainGoogleTokens();
    final auth = SupabaseBootstrap.client.auth;
    final user = auth.currentUser;

    // Prefer linking so anonymous rides / profile UUID stay intact.
    if (user != null && user.isAnonymous) {
      try {
        final linked = await auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: tokens.idToken,
          accessToken: tokens.accessToken,
        );
        await _afterIdentity(linked.user ?? auth.currentUser);
        return linked;
      } on AuthException catch (e) {
        // Identity already belongs to another account → fall through to sign-in.
        debugPrint('Auth link Google: ${e.message}');
      }
    }

    final signedIn = await auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    await _afterIdentity(signedIn.user ?? auth.currentUser);
    return signedIn;
  }

  Future<NativeIdTokens> _obtainGoogleTokens() async {
    await _ensureGoogleInitialized();

    final scopes = ['email', 'profile'];
    final googleSignIn = GoogleSignIn.instance;

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate(scopeHint: scopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthException('Sign-in canceled');
      }
      throw AuthException('Google sign-in failed: ${e.description ?? e.code}');
    }

    final authorization = await googleUser.authorizationClient
            .authorizationForScopes(scopes) ??
        await googleUser.authorizationClient.authorizeScopes(scopes);

    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException('No Google ID token — check GOOGLE_WEB_CLIENT_ID');
    }

    return NativeIdTokens(
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
    if (webClientId.isEmpty) {
      throw AuthException(
        'Missing GOOGLE_WEB_CLIENT_ID in apps/mobile/.env '
        '(Web OAuth client from Google Cloud)',
      );
    }
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
      clientId: (iosClientId != null && iosClientId.isNotEmpty)
          ? iosClientId
          : null,
    );
    _googleReady = true;
  }

  Future<void> signOut({bool restoreAnonymousGuest = true}) async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('Google signOut: $e');
    }
    if (SupabaseBootstrap.isReady) {
      await SupabaseBootstrap.client.auth.signOut();
    }
    if (restoreAnonymousGuest) {
      try {
        await SupabaseBootstrap.ensureSession();
      } catch (e) {
        debugPrint('Auth restore anonymous: $e');
      }
    }
  }

  Future<void> _afterIdentity(User? user) async {
    if (user == null) return;
    await SupabaseBootstrap.ensureProfileForUser(user.id);
    await _seedDisplayName(user);
  }

  Future<void> _seedDisplayName(User user) async {
    final name = displayLabel;
    if (name == null || name.isEmpty) return;
    try {
      final row = await SupabaseBootstrap.client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();
      final existing = row?['display_name'] as String?;
      if (existing != null && existing.trim().isNotEmpty) return;
      await SupabaseBootstrap.client.from('profiles').update({
        'display_name': name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Auth seed display_name: $e');
    }
  }
}
