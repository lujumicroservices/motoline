import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/locale_provider.dart';
import '../../providers/pro_entitlement_provider.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import '../../theme/ride_viz_palette.dart';
import '../../widgets/account_auth_section.dart';
import '../../widgets/pro_upsell.dart';
import '../../widgets/rider_alias_chip.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  Future<void> _syncCloud() async {
    final l10n = context.l10n;
    setState(() => _syncing = true);
    try {
      final result =
          await ref.read(rideSyncServiceProvider).syncAllCompletedRides();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.syncCloudRidesDone(result.ok, result.fail)),
        ),
      );
      ref.invalidate(ridesListProvider);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPro = ref.watch(isProProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: RiderAliasChip(compact: true)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          RiderLabMark(
            size: BrandMarkSize.title,
            showAccentBar: true,
            showAttribution: true,
            attribution: l10n.byRawThrottle,
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: RiderAliasChip(),
          ),
          const SizedBox(height: 28),
          const AccountAuthSection(),
          const SizedBox(height: 28),
          Text(
            l10n.syncCloudRides,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.syncCloudRidesHelp,
            style: GoogleFonts.outfit(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _syncing ? null : _syncCloud,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_syncing ? '…' : l10n.syncCloudRides),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.proUnlock,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.proUnlockBody,
            style: GoogleFonts.outfit(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.proToggleDev,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.proToggleHelp,
              style: GoogleFonts.outfit(
                color: AppTheme.steel,
                fontSize: 12,
              ),
            ),
            value: isPro,
            activeThumbColor: RideVizPalette.leanLeft,
            onChanged: (v) => ref.read(isProProvider.notifier).setPro(v),
          ),
          const SizedBox(height: 8),
          if (!isPro)
            OutlinedButton(
              onPressed: () => showProUpsellSheet(context, ref),
              child: Text(l10n.upgradeToPro),
            )
          else
            Row(
              children: [
                Icon(Icons.verified, color: RideVizPalette.leanLeft, size: 18),
                const SizedBox(width: 8),
                Text(
                  l10n.proUnlocked,
                  style: GoogleFonts.outfit(
                    color: RideVizPalette.leanLeft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 32),
          Text(
            l10n.language,
            style: GoogleFonts.syne(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              locale.languageCode == 'es' ? l10n.spanish : l10n.english,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            trailing: TextButton(
              onPressed: () => ref.read(localeProvider.notifier).toggle(),
              child: Text(l10n.language),
            ),
          ),
        ],
      ),
    );
  }
}
