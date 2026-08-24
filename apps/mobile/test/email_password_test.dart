import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/auth/email_password.dart';

void main() {
  test('validateEmailPassword rejects empty and malformed email', () {
    expect(
      validateEmailPassword(email: '', password: 'secret1'),
      EmailPasswordIssue.emptyEmail,
    );
    expect(
      validateEmailPassword(email: 'not-an-email', password: 'secret1'),
      EmailPasswordIssue.invalidEmail,
    );
  });

  test('validateEmailPassword rejects short passwords', () {
    expect(
      validateEmailPassword(email: 'review@riderlab.app', password: '12345'),
      EmailPasswordIssue.shortPassword,
    );
  });

  test('validateEmailPassword accepts a review-style login', () {
    expect(
      validateEmailPassword(
        email: ' review@riderlab.app ',
        password: 'secret1',
      ),
      isNull,
    );
  });

  test('classifyEmailAuthError maps common Supabase messages', () {
    expect(
      classifyEmailAuthError('Invalid login credentials'),
      EmailAuthServerIssue.invalidCredentials,
    );
    expect(
      classifyEmailAuthError('Email not confirmed'),
      EmailAuthServerIssue.emailNotConfirmed,
    );
    expect(
      classifyEmailAuthError('User already registered'),
      EmailAuthServerIssue.alreadyRegistered,
    );
  });
}
