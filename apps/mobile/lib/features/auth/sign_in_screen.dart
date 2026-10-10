import 'package:flutter/material.dart';

import '../../core/legal/legal_urls.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import 'sign_in_form.dart';

/// Full-screen gate: nothing in RiderLab works until a real account exists.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            const Center(child: RiderLabMark(size: BrandMarkSize.hero)),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              textAlign: TextAlign.center,
              style: AppFonts.body(fontSize: 16, color: AppTheme.steel),
            ),
            const SizedBox(height: 36),
            Text(
              l10n.authGateTitle,
              style: AppFonts.display(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.authGateBody,
              style: AppFonts.body(
                fontSize: 15,
                height: 1.45,
                color: AppTheme.steel,
              ),
            ),
            const SizedBox(height: 24),
            const SignInForm(),
            const SizedBox(height: 20),
            Text(
              l10n.authLegalFooter,
              textAlign: TextAlign.center,
              style: AppFonts.body(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.steel,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () =>
                      openLegalUrlOrSnack(context, LegalUrls.terms),
                  child: Text(l10n.termsTitle),
                ),
                TextButton(
                  onPressed: () =>
                      openLegalUrlOrSnack(context, LegalUrls.privacy),
                  child: Text(l10n.privacyTitle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
