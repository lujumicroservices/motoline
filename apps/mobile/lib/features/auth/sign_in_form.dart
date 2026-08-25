import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/auth_provider_kind.dart';
import '../../core/auth/email_password.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';

/// Google + email/password controls. Used on the auth gate and (rarely)
/// Settings if a leftover guest session is still present.
class SignInForm extends ConsumerStatefulWidget {
  const SignInForm({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  @override
  ConsumerState<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<SignInForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _afterOk() async {
    if (!mounted) return;
    widget.onSignedIn?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.accountSignedInSnack)),
    );
  }

  Future<void> _google(AuthProviderKind provider) async {
    final ok = await ref.read(authActionsProvider).signIn(provider);
    if (ok) await _afterOk();
  }

  Future<void> _forgotPassword() async {
    final l10n = context.l10n;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ref.read(authErrorProvider.notifier).state = l10n.authInvalidEmail;
      return;
    }
    final ok = await ref.read(authActionsProvider).requestPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authResetEmailSent)),
      );
    }
  }

  Future<void> _submit({required bool create}) async {
    final l10n = context.l10n;
    final issue = validateEmailPassword(
      email: _email.text,
      password: _password.text,
    );
    if (issue != null) {
      ref.read(authErrorProvider.notifier).state = switch (issue) {
        EmailPasswordIssue.emptyEmail ||
        EmailPasswordIssue.invalidEmail =>
          l10n.authInvalidEmail,
        EmailPasswordIssue.shortPassword => l10n.authShortPassword,
      };
      return;
    }

    final actions = ref.read(authActionsProvider);
    final ok = create
        ? await actions.signUpWithEmail(_email.text, _password.text)
        : await actions.signInWithEmail(_email.text, _password.text);
    if (ok) await _afterOk();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final auth = ref.watch(authServiceProvider);
    final busy = ref.watch(authBusyProvider);
    final error = ref.watch(authErrorProvider);

    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in auth.availableProviders) ...[
          FilledButton.icon(
            onPressed: () => _google(provider),
            icon: Icon(_iconFor(provider)),
            label: Text(l10n.signInWith(provider.label)),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.mist,
              foregroundColor: AppTheme.asphalt,
            ),
          ),
          const SizedBox(height: 8),
        ],
        _orDivider(l10n),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: _fieldDecoration(l10n.authEmailLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: _hidePassword,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(create: false),
          decoration: _fieldDecoration(l10n.authPasswordLabel).copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => _submit(create: false),
          child: Text(l10n.authSignInEmail),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: busy ? null : _forgotPassword,
            child: Text(l10n.authForgotPassword),
          ),
        ),
        TextButton(
          onPressed: () => _submit(create: true),
          child: Text(l10n.authCreateAccount),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _localizeAuthError(l10n, error),
            style: GoogleFonts.rajdhani(
              color: AppTheme.signal,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppTheme.asphalt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _orDivider(AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            l10n.authOrEmail,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  IconData _iconFor(AuthProviderKind provider) {
    return switch (provider) {
      AuthProviderKind.google => Icons.g_mobiledata_rounded,
    };
  }
}

String _localizeAuthError(AppLocalizations l10n, String raw) {
  return switch (classifyEmailAuthError(raw)) {
    EmailAuthServerIssue.invalidCredentials => l10n.authInvalidCredentials,
    EmailAuthServerIssue.emailNotConfirmed ||
    EmailAuthServerIssue.needsEmailConfirm =>
      l10n.authConfirmEmailThenSignIn,
    EmailAuthServerIssue.alreadyRegistered => l10n.authEmailAlreadyRegistered,
    EmailAuthServerIssue.unknown => raw,
  };
}
