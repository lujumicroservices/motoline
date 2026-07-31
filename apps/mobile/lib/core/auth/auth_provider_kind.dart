/// Supported cloud identity providers. Add new cases as providers ship
/// (Apple, email magic-link, etc.) — keep UI and [AuthService] switch-based.
enum AuthProviderKind {
  google,
  // apple,
  // email,
}

extension AuthProviderKindX on AuthProviderKind {
  String get id => switch (this) {
        AuthProviderKind.google => 'google',
      };

  String get label => switch (this) {
        AuthProviderKind.google => 'Google',
      };
}
