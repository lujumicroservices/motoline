import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/auth/auth_provider_kind.dart';
import '../l10n/l10n_ext.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';

/// Account / identity block for Settings — Google now, more providers later.
class AccountAuthSection extends ConsumerWidget {
  const AccountAuthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authServiceProvider);
    final permanent = ref.watch(hasPermanentIdentityProvider);
    final busy = ref.watch(authBusyProvider);
    final error = ref.watch(authErrorProvider);
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
          permanent ? l10n.accountSignedInBody : l10n.accountGuestBody,
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
                              : l10n.accountGuest,
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
              else if (!permanent) ...[
                for (final provider in auth.availableProviders) ...[
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await ref
                          .read(authActionsProvider)
                          .signIn(provider);
                      if (!context.mounted || !ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.accountSignedInSnack)),
                      );
                    },
                    icon: Icon(_iconFor(provider)),
                    label: Text(l10n.signInWith(provider.label)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.mist,
                      foregroundColor: AppTheme.asphalt,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ] else
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(authActionsProvider).signOut();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.accountSignedOutSnack)),
                    );
                  },
                  child: Text(l10n.signOut),
                ),
            ],
          ),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            error,
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

  IconData _iconFor(AuthProviderKind provider) {
    return switch (provider) {
      AuthProviderKind.google => Icons.g_mobiledata_rounded,
    };
  }
}
