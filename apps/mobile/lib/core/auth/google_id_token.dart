import 'dart:convert';
import 'dart:math';

/// Random nonce for Google Credential Manager + Supabase `signInWithIdToken`.
String newGoogleNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)])
      .join();
}

/// Play-signed builds fail native Google Sign-In with Credential Manager [16]
/// when the Android OAuth client is missing the deployment SHA-1.
bool isGoogleReauthFailure(String message) {
  final m = message.toLowerCase();
  return m.contains('[16]') || m.contains('reauth failed');
}

/// Reads the `nonce` claim from a Google ID token JWT.
String? nonceClaimFromIdToken(String idToken) {
  try {
    final parts = idToken.split('.');
    if (parts.length < 2) return null;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final nonce = payload['nonce'];
    if (nonce is! String) return null;
    final trimmed = nonce.trim();
    return trimmed.isEmpty ? null : trimmed;
  } catch (_) {
    return null;
  }
}
