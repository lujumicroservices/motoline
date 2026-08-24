import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/auth/impersonation_controller.dart';
import '../../core/notifications/push_diagnostics.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/bike_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/pro_entitlement_provider.dart';
import '../../providers/ride_providers.dart';
import '../../core/services/ride_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import '../../theme/ride_viz_palette.dart';
import '../../widgets/account_auth_section.dart';
import '../../widgets/partner_code_redeem.dart';
import '../../widgets/pro_upsell.dart';
import '../../widgets/rider_alias_chip.dart';
import '../adventure_camera/widgets/adventure_camera_settings_section.dart';
import '../home/home_nav_icons.dart';
import '../lean_lab/lean_imu_lab_screen.dart';
import '../lean_lab/lean_lab_screen.dart';
import 'bike_picker_screen.dart';
import 'impersonate_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    PushDiagnostics.hydrate().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _syncCloud() async {
    final l10n = context.l10n;
    if (ref.read(impersonationProvider).active) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.impersonateNoSync)),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final sync = ref.read(rideSyncServiceProvider);
      final outbox = ref.read(syncOutboxServiceProvider);
      final drained = await outbox.drain(limit: 40);
      final result = await sync.syncAllCompletedRides();
      final combinedOk = drained.ok + result.ok;
      final combinedFail = drained.fail + result.fail;
      final pulled = await sync.pullMyCloudRides(
        policy: TrackPullPolicy.preferRicher,
      );
      final leanPulled =
          await LeanLabService.instance.pullMyCloudSessions();
      if (!mounted) return;
      final err = sync.lastSyncError ?? sync.lastPullError;
      final detail = err == null ? '' : '\n$err';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: err == null ? 4 : 10),
          content: Text(
            '${l10n.syncCloudRidesDone(combinedOk, combinedFail)} · '
            '${l10n.syncCloudRidesPulled(pulled, leanPulled)}'
            '$detail',
          ),
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
    final pro = ref.watch(proEntitlementProvider);
    final locale = ref.watch(localeProvider);
    final bike = ref.watch(riderBikeProvider);

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
          const SizedBox(height: 20),
          Text(
            l10n.labsSectionTitle,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.labsSectionHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppMotoIcon(size: 28, color: AppTheme.line),
            title: Text(
              l10n.leanLabSettingsTile,
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.leanLabSettingsHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeanLabScreen(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.sensors, color: AppTheme.lineHot),
            title: Text(
              l10n.leanImuLabSettingsTile,
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              l10n.leanImuLabSettingsHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeanImuLabScreen(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined, color: AppTheme.mist),
            title: Text(
              l10n.pushDiagnosticsTitle,
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
            ),
            subtitle: SelectableText(
              PushDiagnostics.history.isEmpty
                  ? l10n.pushDiagnosticsEmpty
                  : PushDiagnostics.history.reversed.take(5).join('\n'),
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 12,
              ),
            ),
            trailing: PushDiagnostics.history.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.pushDiagnosticsTitle,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: PushDiagnostics.history.join('\n'),
                        ),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.pushDiagnosticsCopied)),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.bikeSection,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const AppMotoIcon(size: 28, color: AppTheme.mist),
            title: Text(
              bike?.label ?? l10n.bikeSelect,
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              bike == null ? l10n.bikeSelectHelp : bike.subtitle,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BikePickerScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            l10n.language,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate, color: AppTheme.mist),
            title: Text(
              locale.languageCode == 'es' ? l10n.spanish : l10n.english,
              style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
            ),
            trailing: TextButton(
              onPressed: () => ref.read(localeProvider.notifier).toggle(),
              child: Text(
                locale.languageCode == 'es' ? l10n.english : l10n.spanish,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const AccountAuthSection(),
          if (ref.watch(impersonationProvider).staff &&
              !ref.watch(impersonationProvider).active) ...[
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.visibility, color: AppTheme.signal),
              title: Text(
                l10n.impersonateTile,
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.impersonateHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImpersonateScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const _StaffPartnerCodeTile(),
          ],
          const SizedBox(height: 28),
          const AdventureCameraSettingsSection(),
          const SizedBox(height: 28),
          Text(
            l10n.syncCloudRides,
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.syncCloudRidesHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _syncing || ref.watch(impersonationProvider).active
                ? null
                : _syncCloud,
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
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.proUnlockBody,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (proRemainingLabel(l10n, pro) != null) ...[
            const SizedBox(height: 8),
            Text(
              proRemainingLabel(l10n, pro)!,
              style: GoogleFonts.rajdhani(
                color: RideVizPalette.leanLeft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (pro.expiredAfterGrant) ...[
            const SizedBox(height: 8),
            Text(
              l10n.proExpiredKeepLab,
              style: GoogleFonts.rajdhani(
                color: AppTheme.signal,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (allowLocalProToggle)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.proToggleDev,
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                l10n.proToggleHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              value: isPro,
              activeThumbColor: RideVizPalette.leanLeft,
              onChanged: (v) =>
                  ref.read(proEntitlementProvider.notifier).setPro(v),
            ),
          if (revenueCatConfigured) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await ref
                    .read(proEntitlementProvider.notifier)
                    .restorePurchases();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.proUnlocked)),
                );
              },
              child: Text(l10n.restorePurchases),
            ),
          ],
          const SizedBox(height: 12),
          const PartnerCodeRedeemField(),
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
                Expanded(
                  child: Text(
                    proRemainingLabel(l10n, pro) ?? l10n.proUnlocked,
                    style: GoogleFonts.rajdhani(
                      color: RideVizPalette.leanLeft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StaffPartnerCodeTile extends ConsumerStatefulWidget {
  const _StaffPartnerCodeTile();
  @override
  ConsumerState<_StaffPartnerCodeTile> createState() =>
      _StaffPartnerCodeTileState();
}

class _StaffPartnerCodeTileState extends ConsumerState<_StaffPartnerCodeTile> {
  final _label = TextEditingController();
  bool _busy = false;
  String? _lastCode;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final result = await ref
        .read(proEntitlementProvider.notifier)
        .staffCreatePartnerCode(label: _label.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok || result.code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.partnerCodeInvalid)),
      );
      return;
    }
    setState(() => _lastCode = result.code);
    await Clipboard.setData(ClipboardData(text: result.code!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.partnerCodeCopied(result.code!))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.createPartnerCode,
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.createPartnerCodeHelp,
          style: GoogleFonts.rajdhani(
            color: AppTheme.steel,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _label,
          decoration: InputDecoration(
            hintText: l10n.partnerLabelHint,
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _create,
          child: Text(l10n.createPartnerCode),
        ),
        if (_lastCode != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            _lastCode!,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}
