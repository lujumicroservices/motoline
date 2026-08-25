import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/auth/email_password.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';

/// Shown when the recovery deep link opens the app (PASSWORD_RECOVERY).
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final p = _password.text;
    final c = _confirm.text;
    if (p.length < kMinAuthPasswordLength) {
      setState(() => _error = l10n.authShortPassword);
      return;
    }
    if (p != c) {
      setState(() => _error = l10n.authPasswordMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authActionsProvider).updatePassword(p);
      if (!mounted) return;
      setState(() {
        _done = true;
        _busy = false;
      });
      ref.read(passwordRecoveryActiveProvider.notifier).state = false;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(title: Text(l10n.authSetPasswordTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              l10n.authSetPasswordBody,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_done)
              Text(
                l10n.authPasswordUpdated,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.line,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            else ...[
              TextField(
                controller: _password,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.authNewPasswordLabel,
                  filled: true,
                  fillColor: AppTheme.asphaltElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _hide = !_hide),
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _hide,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.authConfirmPasswordLabel,
                  filled: true,
                  fillColor: AppTheme.asphaltElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.authSavePassword),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.signal,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
