import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/push_notification_service.dart';
import '../supabase/supabase_bootstrap.dart';
import 'auth_provider_kind.dart';

/// Tokens obtained from a native OAuth SDK (Google today; Apple later).
class NativeIdTokens {
  const NativeIdTokens({
    required this.idToken,
    this.accessToken,
    this.displayName,
    this.email,
  });

  final String idToken;
  final String? accessToken;
  /// From the native SDK (more reliable than waiting for Supabase metadata).
  final String? displayName;
  final String? email;
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

  String? get displayLabel => preferredDisplayName(currentUser);

  /// Best public name for a linked Google (or other) account.
  String? preferredDisplayName(User? user, {String? googleDisplayName}) {
    if (user == null &&
        (googleDisplayName == null || googleDisplayName.trim().isEmpty)) {
      return null;
    }
    final fromGoogle = googleDisplayName?.trim();
    if (fromGoogle != null && fromGoogle.isNotEmpty) return fromGoogle;

    if (user == null) return null;

    final meta = user.userMetadata;
    final fromMeta = _firstNonEmpty([
      meta?['full_name'],
      meta?['name'],
      meta?['user_name'],
      meta?['preferred_username'],
    ]);
    if (fromMeta != null) return fromMeta;

    for (final identity in user.identities ?? const <UserIdentity>[]) {
      if (identity.provider == 'anonymous') continue;
      final data = identity.identityData;
      final fromIdentity = _firstNonEmpty([
        data?['full_name'],
        data?['name'],
        data?['user_name'],
        data?['preferred_username'],
      ]);
      if (fromIdentity != null) return fromIdentity;
      final identityEmail = (data?['email'] as String?)?.trim();
      if (identityEmail != null && identityEmail.isNotEmpty) {
        return identityEmail;
      }
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
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
        await _afterIdentity(
          linked.user ?? auth.currentUser,
          googleDisplayName: tokens.displayName,
          googleEmail: tokens.email,
        );
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
    await _afterIdentity(
      signedIn.user ?? auth.currentUser,
      googleDisplayName: tokens.displayName,
      googleEmail: tokens.email,
    );
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
      displayName: googleUser.displayName,
      email: googleUser.email,
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
      await PushNotificationService.instance.clearToken();
    } catch (e) {
      debugPrint('FCM clear on signOut: $e');
    }
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
        await PushNotificationService.instance.syncToken();
      } catch (e) {
        debugPrint('Auth restore anonymous: $e');
      }
    }
  }

  Future<void> _afterIdentity(
    User? user, {
    String? googleDisplayName,
    String? googleEmail,
  }) async {
    if (user == null) return;
    // Refresh so email / identities land on currentUser after link.
    try {
      await SupabaseBootstrap.client.auth.refreshSession();
    } catch (e) {
      debugPrint('Auth refresh after identity: $e');
    }
    final refreshed =
        SupabaseBootstrap.client.auth.currentUser ?? user;
    await SupabaseBootstrap.ensureProfileForUser(refreshed.id);
    await syncLinkedProfile(
      user: refreshed,
      googleDisplayName: googleDisplayName,
      googleEmail: googleEmail,
      force: true,
    );
    await PushNotificationService.instance.syncToken();
  }

  /// Writes Google (or other linked) name into `profiles.display_name` so
  /// Amigos / alias chip / ride share all show the email account name.
  Future<String?> syncLinkedProfile({
    User? user,
    String? googleDisplayName,
    String? googleEmail,
    bool force = false,
  }) async {
    final u = user ?? currentUser;
    if (u == null) return null;
    if (u.isAnonymous && !force) return null;

    final name = preferredDisplayName(
      u,
      googleDisplayName: googleDisplayName,
    );
    final email = (googleEmail?.trim().isNotEmpty ?? false)
        ? googleEmail!.trim()
        : u.email?.trim();

    // Prefer Google name; fall back to email so members always see the account.
    final display = (name != null && name.isNotEmpty)
        ? name
        : (email != null && email.isNotEmpty ? email : null);
    if (display == null) return null;

    try {
      await SupabaseBootstrap.client.from('profiles').update({
        'display_name': display,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', u.id);
      return display;
    } catch (e) {
      debugPrint('Auth sync display_name: $e');
      return null;
    }
  }
}
