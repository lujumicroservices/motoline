import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/auth/sign_in_form.dart';
import '../l10n/l10n_ext.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';

/// Account block in Settings. Signed-in riders can sign out (returns to the
/// auth gate). Leftover guests see the same sign-in form as launch.
class AccountAuthSection extends ConsumerWidget {
  const AccountAuthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authServiceProvider);
    final permanent = ref.watch(hasPermanentIdentityProvider);
    final busy = ref.watch(authBusyProvider);
    final label = auth.displayLabel;
    final email = auth.currentUser?.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.accountSection,
          style: GoogleFonts.barlowCondensed(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          permanent ? l10n.accountSignedInBody : l10n.authGateBody,
          style: GoogleFonts.rajdhani(
            color: AppTheme.steel,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.asphaltElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: permanent
                  ? AppTheme.line.withValues(alpha: 0.35)
                  : AppTheme.mist.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    permanent ? Icons.verified_user : Icons.person_outline,
                    color: permanent ? AppTheme.line : AppTheme.steel,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          permanent
                              ? (label ?? l10n.accountSignedIn)
                              : l10n.authGateTitle,
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (permanent && email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (busy)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (!permanent)
                const SignInForm()
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(authActionsProvider).signOut();
                        if (!context.mounted) return;
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.accountSignedOutSnack)),
                        );
                      },
                      child: Text(l10n.signOut),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.deleteAccountConfirmTitle),
                            content: Text(l10n.deleteAccountConfirmBody),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.signal,
                                ),
                                child: Text(l10n.deleteAccountConfirmAction),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        final deleted =
                            await ref.read(authActionsProvider).deleteAccount();
                        if (!context.mounted) return;
                        if (!deleted) {
                          final err = ref.read(authErrorProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? l10n.deleteAccountFailed),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).popUntil((route) => route.isFirst);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.deleteAccountDoneSnack)),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.signal,
                      ),
                      child: Text(l10n.deleteAccount),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
