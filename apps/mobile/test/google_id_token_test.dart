import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/auth/google_id_token.dart';

String _unsignedJwt(Map<String, Object?> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.sig';
}

void main() {
  test('newGoogleNonce is long enough for Google / Supabase', () {
    final nonce = newGoogleNonce();
    expect(nonce.length, 32);
    expect(newGoogleNonce(), isNot(nonce));
  });

  test('nonceClaimFromIdToken reads the JWT nonce', () {
    final token = _unsignedJwt({'nonce': 'abc-123', 'sub': '1'});
    expect(nonceClaimFromIdToken(token), 'abc-123');
  });

  test('nonceClaimFromIdToken returns null when missing', () {
    expect(nonceClaimFromIdToken(_unsignedJwt({'sub': '1'})), isNull);
    expect(nonceClaimFromIdToken('not-a-jwt'), isNull);
  });

  test('isGoogleReauthFailure detects Credential Manager [16]', () {
    expect(
      isGoogleReauthFailure(
        'Google sign-in did not finish (canceled — [16] Account reauth failed.)',
      ),
      isTrue,
    );
    expect(isGoogleReauthFailure('canceled - [16] Account reauth failed.'), isTrue);
    expect(isGoogleReauthFailure('Account reauth failed'), isTrue);
  });
}
