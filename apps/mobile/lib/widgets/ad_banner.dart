import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../providers/pro_entitlement_provider.dart';
import '../theme/app_theme.dart';
import '../theme/ride_viz_palette.dart';

/// Banner slot for Free users. Hidden when Pro is active.
/// Placeholder until AdMob (or another network) is wired.
class FreeAdBanner extends ConsumerWidget {
  const FreeAdBanner({
    super.key,
    this.onUpgrade,
    this.compact = false,
  });

  final VoidCallback? onUpgrade;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isProProvider)) return const SizedBox.shrink();

    final l10n = context.l10n;
    final height = compact ? 50.0 : 56.0;

    return Material(
      color: AppTheme.asphaltElevated,
      child: InkWell(
        onTap: onUpgrade,
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppTheme.mist.withValues(alpha: 0.08),
              ),
              bottom: BorderSide(
                color: AppTheme.mist.withValues(alpha: 0.08),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mist.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  l10n.adPlaceholder,
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.steel,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.removeAdsWithPro,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    color: AppTheme.mist,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.upgradeToPro,
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: RideVizPalette.leanLeft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
