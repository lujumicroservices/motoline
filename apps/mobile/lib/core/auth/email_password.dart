/// Client-side checks for email + password sign-in / sign-up.
///
/// Supabase default minimum password length is 6.
enum EmailPasswordIssue { emptyEmail, invalidEmail, shortPassword }

const kMinAuthPasswordLength = 6;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

EmailPasswordIssue? validateEmailPassword({
  required String email,
  required String password,
}) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return EmailPasswordIssue.emptyEmail;
  if (!_emailPattern.hasMatch(trimmed)) return EmailPasswordIssue.invalidEmail;
  if (password.length < kMinAuthPasswordLength) {
    return EmailPasswordIssue.shortPassword;
  }
  return null;
}

/// Maps Supabase Auth error text to a stable key for l10n.
enum EmailAuthServerIssue {
  invalidCredentials,
  emailNotConfirmed,
  alreadyRegistered,
  needsEmailConfirm,
  unknown,
}

EmailAuthServerIssue classifyEmailAuthError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invalid login') ||
      lower.contains('invalid credentials') ||
      lower.contains('invalid email or password')) {
    return EmailAuthServerIssue.invalidCredentials;
  }
  if (lower.contains('email not confirmed')) {
    return EmailAuthServerIssue.emailNotConfirmed;
  }
  if (lower.contains('already registered') ||
      lower.contains('user already registered')) {
    return EmailAuthServerIssue.alreadyRegistered;
  }
  if (lower.contains('confirm') && lower.contains('email')) {
    return EmailAuthServerIssue.needsEmailConfirm;
  }
  return EmailAuthServerIssue.unknown;
}
