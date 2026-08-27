import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../providers/pro_entitlement_provider.dart';
import '../theme/app_theme.dart';
import '../theme/ride_viz_palette.dart';
import 'partner_code_redeem.dart';

Future<void> showProUpsellSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.asphaltElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _ProUpsellSheet(),
  );
}

class _ProUpsellSheet extends ConsumerWidget {
  const _ProUpsellSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(proEntitlementProvider);
    final remaining = proRemainingLabel(l10n, status);
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + inset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mist.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.proUnlock,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.proUnlockBody,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              if (remaining != null) ...[
                const SizedBox(height: 10),
                Text(
                  remaining,
                  style: GoogleFonts.rajdhani(
                    color: RideVizPalette.leanLeft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (status.expiredAfterGrant) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.proExpiredKeepLab,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.signal,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _FeatureRow(text: l10n.proFeatureSegment),
              const SizedBox(height: 10),
              _FeatureRow(text: l10n.proFeatureBrakes),
              const SizedBox(height: 10),
              _FeatureRow(text: l10n.proFeatureCurva),
              const SizedBox(height: 24),
              if (status.isPro)
                Text(
                  remaining ?? l10n.proUnlocked,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: RideVizPalette.leanLeft,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else ...[
                FilledButton(
                  onPressed: () async {
                    final ok = await ref
                        .read(proEntitlementProvider.notifier)
                        .purchasePro();
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.of(context).pop();
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.proStoreNotReady)),
                    );
                  },
                  child: Text(l10n.upgradeToPro),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.havePartnerCode,
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const PartnerCodeRedeemField(compact: true),
                const SizedBox(height: 8),
                Text(
                  l10n.startTrialHelp,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 20, color: RideVizPalette.leanLeft),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.rajdhani(fontSize: 14, height: 1.35),
          ),
        ),
      ],
    );
  }
}

/// Compact lock chip used on gated sections.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: RideVizPalette.leanLeft.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: RideVizPalette.leanLeft.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        l10n.pro,
        style: GoogleFonts.rajdhani(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: RideVizPalette.leanLeft,
        ),
      ),
    );
  }
}
