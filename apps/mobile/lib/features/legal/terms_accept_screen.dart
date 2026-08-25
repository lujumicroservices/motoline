import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/legal/legal_urls.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import 'legal_acceptance.dart';

/// Blocking gate after first sign-in until the rider agrees to terms.
class TermsAcceptScreen extends ConsumerStatefulWidget {
  const TermsAcceptScreen({super.key});

  @override
  ConsumerState<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends ConsumerState<TermsAcceptScreen> {
  bool _busy = false;

  Future<void> _agree() async {
    setState(() => _busy = true);
    try {
      await LegalAcceptance.accept();
      ref.invalidate(termsAcceptedProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(authActionsProvider).signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) unawaited(_decline());
      },
      child: Scaffold(
        backgroundColor: AppTheme.asphalt,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.termsAcceptTitle,
                  style: GoogleFonts.exo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      l10n.termsAcceptBody,
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        height: 1.45,
                        color: AppTheme.mist,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => openLegalUrlOrSnack(context, LegalUrls.terms),
                  child: Text(l10n.termsTitle),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => openLegalUrlOrSnack(context, LegalUrls.privacy),
                  child: Text(l10n.privacyTitle),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _agree,
                  child: Text(l10n.termsAcceptAgree),
                ),
                TextButton(
                  onPressed: _busy ? null : _decline,
                  child: Text(l10n.termsAcceptDecline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
