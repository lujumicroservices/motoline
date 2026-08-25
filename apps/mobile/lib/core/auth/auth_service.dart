import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/push_notification_service.dart';
import '../supabase/supabase_bootstrap.dart';
import 'auth_provider_kind.dart';
import 'email_password.dart';
import 'google_id_token.dart';

/// Tokens obtained from a native OAuth SDK (Google today; Apple later).
class NativeIdTokens {
  const NativeIdTokens({
    required this.idToken,
    this.accessToken,
    this.nonce,
    this.displayName,
    this.email,
  });

  final String idToken;
  final String? accessToken;
  /// Matches the nonce claim in [idToken] for Supabase verification.
  final String? nonce;
  /// From the native SDK (more reliable than waiting for Supabase metadata).
  final String? displayName;
  final String? email;
}

/// Extensible auth facade over Supabase.
///
/// The app requires a permanent identity (Google or email). Guest sessions
/// are not used.
class AuthService {
  AuthService();

  /// Deep link registered in AndroidManifest / Info.plist. Also add it in
  /// Supabase → Authentication → URL Configuration → Redirect URLs.
  static const googleOAuthRedirect = 'com.rawthrottle.riderlab://login-callback';

  /// Hosted password-reset page (computer + phone browser).
  /// Site URL / Redirect URLs must include this path.
  static const passwordResetRedirect =
      'https://riderlab.rawthrottle.com.mx/auth/reset-password/';

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

  /// Existing email account.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _assertEmailPassword(email, password);
    if (!SupabaseBootstrap.isReady) {
      throw AuthException('Cloud is not configured');
    }
    final auth = SupabaseBootstrap.client.auth;
    final signedIn = await auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _afterIdentity(signedIn.user ?? auth.currentUser);
    return signedIn;
  }

  /// Sends the Supabase recovery email. Opens the hosted reset page on any device.
  Future<void> requestPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw AuthException('Enter a valid email address.');
    }
    if (!SupabaseBootstrap.isReady) {
      throw AuthException('Cloud is not configured');
    }
    await SupabaseBootstrap.client.auth.resetPasswordForEmail(
      trimmed,
      redirectTo: passwordResetRedirect,
    );
  }

  /// Completes recovery after [AuthChangeEvent.passwordRecovery] (deep link).
  Future<void> updatePassword(String password) async {
    if (password.length < kMinAuthPasswordLength) {
      throw AuthException(
        'Password must be at least $kMinAuthPasswordLength characters.',
      );
    }
    if (!SupabaseBootstrap.isReady) {
      throw AuthException('Cloud is not configured');
    }
    await SupabaseBootstrap.client.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  /// New email account.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _assertEmailPassword(email, password);
    if (!SupabaseBootstrap.isReady) {
      throw AuthException('Cloud is not configured');
    }
    final auth = SupabaseBootstrap.client.auth;
    final signedUp = await auth.signUp(
      email: email.trim(),
      password: password,
    );
    if (signedUp.session == null) {
      throw AuthException(
        'Confirm the email we sent, then sign in.',
      );
    }
    await _afterIdentity(signedUp.user ?? auth.currentUser);
    return signedUp;
  }

  void _assertEmailPassword(String email, String password) {
    final issue = validateEmailPassword(email: email, password: password);
    if (issue == null) return;
    throw AuthException(switch (issue) {
      EmailPasswordIssue.emptyEmail ||
      EmailPasswordIssue.invalidEmail =>
        'Enter a valid email address.',
      EmailPasswordIssue.shortPassword =>
        'Password must be at least $kMinAuthPasswordLength characters.',
    });
  }

  Future<AuthResponse> _signInWithGoogle() async {
    try {
      return await _signInWithGoogleNative();
    } on AuthException catch (e) {
      if (!isGoogleReauthFailure(e.message)) rethrow;
      debugPrint('Native Google [16], falling back to browser OAuth: ${e.message}');
      return _signInWithGoogleBrowser();
    }
  }

  Future<AuthResponse> _signInWithGoogleNative() async {
    final tokens = await _obtainGoogleTokens();
    final auth = SupabaseBootstrap.client.auth;

    final signedIn = await auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
      nonce: tokens.nonce,
    );
    await _afterIdentity(
      signedIn.user ?? auth.currentUser,
      googleDisplayName: tokens.displayName,
      googleEmail: tokens.email,
    );
    return signedIn;
  }

  /// Browser OAuth uses the Web client (already in Supabase). It does not
  /// check the Play APK SHA-1, so it works when Credential Manager returns [16].
  Future<AuthResponse> _signInWithGoogleBrowser() async {
    final auth = SupabaseBootstrap.client.auth;
    final completer = Completer<AuthResponse>();
    final sub = auth.onAuthStateChange.listen((data) {
      if (completer.isCompleted) return;
      final session = data.session;
      final signedIn = session?.user;
      if (signedIn == null || signedIn.isAnonymous) return;
      completer.complete(AuthResponse(session: session, user: signedIn));
    });

    try {
      final opened = await auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: googleOAuthRedirect,
      );
      if (!opened) {
        throw AuthException('Could not open Google sign-in in the browser');
      }
      final result = await completer.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw AuthException(
          'Google browser sign-in timed out. Add redirect URL '
          '$googleOAuthRedirect in Supabase → Auth → URL configuration.',
        ),
      );
      await _afterIdentity(result.user ?? auth.currentUser);
      return result;
    } finally {
      await sub.cancel();
    }
  }

  Future<NativeIdTokens> _obtainGoogleTokens() async {
    final rawNonce = newGoogleNonce();
    await _ensureGoogleInitialized(nonce: rawNonce);

    final scopes = ['email', 'profile'];
    final googleSignIn = GoogleSignIn.instance;

    // Sideload (upload key) then Play (app-signing key) leaves a cached
    // Google session. Credential Manager then fails with [16] reauth.
    try {
      await googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google signOut before authenticate: $e');
    }

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate(scopeHint: scopes);
    } on GoogleSignInException catch (e) {
      throw AuthException(_googleSignInMessage(e));
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException('No Google ID token — check GOOGLE_WEB_CLIENT_ID');
    }

    // ID token is enough for Supabase. A second Google consent sheet
    // (authorizeScopes) is often reported as "canceled" on Play-signed builds.
    String? accessToken;
    try {
      final existing =
          await googleUser.authorizationClient.authorizationForScopes(scopes);
      accessToken = existing?.accessToken;
    } on GoogleSignInException catch (e) {
      debugPrint('Google access token skipped: ${_googleSignInMessage(e)}');
    }

    return NativeIdTokens(
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonceClaimFromIdToken(idToken) ?? rawNonce,
      displayName: googleUser.displayName,
      email: googleUser.email,
    );
  }

  static String _googleSignInMessage(GoogleSignInException e) {
    final details = [
      e.code.name,
      e.description,
      e.details?.toString(),
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' — ');
    if (e.code == GoogleSignInExceptionCode.canceled) {
      return 'Google sign-in did not finish ($details). '
          'If you did not tap Back: Play quantum-ready signing needs an Android '
          'OAuth client for the deployment/previous SHA-1 (Download certificates), '
          'not only Classical/PQC. Package com.rawthrottle.riderlab, project riderlab-7b183.';
    }
    return 'Google sign-in failed: $details';
  }

  Future<void> _ensureGoogleInitialized({String? nonce}) async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
    if (webClientId.isEmpty) {
      throw AuthException(
        'Missing GOOGLE_WEB_CLIENT_ID in apps/mobile/.env '
        '(Web OAuth client from Google Cloud)',
      );
    }
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim();
    final useIosClient = !kIsWeb &&
        Platform.isIOS &&
        iosClientId != null &&
        iosClientId.isNotEmpty;
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId,
      clientId: useIosClient ? iosClientId : null,
      nonce: nonce,
    );
  }

  Future<void> signOut() async {
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
