import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/auth/impersonation_controller.dart';
import '../../core/legal/legal_urls.dart';
import '../../core/notifications/push_diagnostics.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/auth_providers.dart';
import '../../providers/force_start_prefs.dart';
import '../../providers/locale_provider.dart';
import '../../providers/pro_entitlement_provider.dart';
import '../../providers/ride_providers.dart';
import '../../providers/rodada_share_prefs.dart';
import '../../core/services/ride_sync_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import '../../theme/ride_viz_palette.dart';
import '../../widgets/account_auth_section.dart';
import '../../widgets/partner_code_redeem.dart';
import '../../widgets/pro_upsell.dart';
import '../../widgets/rider_alias_chip.dart';
import '../adventure_camera/widgets/adventure_camera_settings_section.dart';
import '../experimental/gps_track_points_lab_screen.dart';
import 'widgets/app_version_tile.dart';
import '../home/home_nav_icons.dart';
import '../lean_lab/lean_imu_lab_screen.dart';
import '../lean_lab/lean_lab_screen.dart';
import '../moderation/content_guidelines.dart';
import '../moderation/staff_reports_screen.dart';
import '../ride_active/location_permission_gate.dart';
import '../rodadas/rodada_providers.dart';
import '../watch/family_circle_screen.dart';
import 'impersonate_screen.dart';
import 'settings_group.dart';
import '../../widgets/app_snack.dart';

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
      showAppSnack(context, l10n.impersonateNoSync);
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
      final leanPulled = await LeanLabService.instance.pullMyCloudSessions();
      if (!mounted) return;
      final err = sync.lastSyncError ?? sync.lastPullError;
      final detail = err == null ? '' : '\n$err';
      showAppSnack(
        context,
        '${l10n.syncCloudRidesDone(combinedOk, combinedFail)} · '
        '${l10n.syncCloudRidesPulled(pulled, leanPulled)}'
        '$detail',
        duration: Duration(seconds: err == null ? 4 : 10),
      );
      ref.invalidate(ridesListProvider);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pushShareToRodadas() async {
    await syncShareSettingsToOpenRodadas(
      repo: ref.read(rodadaRepositoryProvider),
      settings: ref.read(rodadaSharePrefsProvider),
    );
    ref.invalidate(myRodadasProvider);
  }

  TextStyle get _tileTitle =>
      GoogleFonts.rajdhani(fontWeight: FontWeight.w600);

  TextStyle get _tileSub =>
      GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPro = ref.watch(isProProvider);
    final pro = ref.watch(proEntitlementProvider);
    final locale = ref.watch(localeProvider);
    final share = ref.watch(rodadaSharePrefsProvider);
    final signedIn = ref.watch(hasPermanentIdentityProvider);
    final accountGroup = SettingsGroup(
      title: l10n.accountSection,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.translate, color: AppTheme.mist),
          title: Text(
            locale.languageCode == 'es' ? l10n.spanish : l10n.english,
            style: _tileTitle,
          ),
          trailing: TextButton(
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
            child: Text(
              locale.languageCode == 'es' ? l10n.english : l10n.spanish,
            ),
          ),
        ),
        const AccountAuthSection(),
      ],
    );

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
          const Align(alignment: Alignment.centerLeft, child: RiderAliasChip()),
          const SizedBox(height: 8),
          const AppVersionTile(),
          if (!signedIn) accountGroup,
          SettingsGroup(
            title: l10n.settingsShareSection,
            help: l10n.settingsShareSectionHelp,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoArmOnRodadaStart, style: _tileTitle),
                subtitle: Text(l10n.autoArmOnRodadaStartHelp, style: _tileSub),
                value: share.autoArmOnStart,
                activeThumbColor: RideVizPalette.leanLeft,
                onChanged: (v) async {
                  if (v) {
                    final ok =
                        await LocationPermissionGate.requestForRecording(
                          context,
                        );
                    if (!ok || !context.mounted) return;
                  }
                  await ref
                      .read(rodadaSharePrefsProvider.notifier)
                      .setAutoArmOnStart(v);
                  await _pushShareToRodadas();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.shareLocationOnRoute, style: _tileTitle),
                subtitle: Text(l10n.shareLocationEvery5Min, style: _tileSub),
                value: share.shareLive,
                activeThumbColor: RideVizPalette.leanLeft,
                onChanged: (v) async {
                  if (v) {
                    final ok =
                        await LocationPermissionGate.requestForRodadaLive(
                          context,
                        );
                    if (!ok || !context.mounted) return;
                  }
                  await ref
                      .read(rodadaSharePrefsProvider.notifier)
                      .setShareLive(v);
                  await _pushShareToRodadas();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.autoShareFamilyOnRodada, style: _tileTitle),
                subtitle: Text(
                  l10n.autoShareFamilyOnRodadaHelp,
                  style: _tileSub,
                ),
                value: share.autoShareFamily,
                activeThumbColor: RideVizPalette.leanLeft,
                onChanged: (v) async {
                  if (v) {
                    final ok =
                        await LocationPermissionGate.requestForRodadaLive(
                          context,
                        );
                    if (!ok || !context.mounted) return;
                  }
                  await ref
                      .read(rodadaSharePrefsProvider.notifier)
                      .setAutoShareFamily(v);
                  await _pushShareToRodadas();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.shareTrackAfterRides, style: _tileTitle),
                value: share.shareTrack,
                activeThumbColor: RideVizPalette.leanLeft,
                onChanged: (v) async {
                  await ref
                      .read(rodadaSharePrefsProvider.notifier)
                      .setShareTrack(v);
                  await _pushShareToRodadas();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite, color: AppTheme.lineHot),
                title: Text(l10n.familyRodadaTipTitle, style: _tileTitle),
                subtitle: Text(l10n.familyRodadaTipBody, style: _tileSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyCircleScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          SettingsGroup(
            title: l10n.proUnlock,
            children: [
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
              const SizedBox(height: 12),
              if (allowLocalProToggle)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.proToggleDev, style: _tileTitle),
                  subtitle: Text(l10n.proToggleHelp, style: _tileSub),
                  value: isPro,
                  activeThumbColor: RideVizPalette.leanLeft,
                  onChanged: (v) =>
                      ref.read(proEntitlementProvider.notifier).setPro(v),
                ),
              if (revenueCatConfigured) ...[
                OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(proEntitlementProvider.notifier)
                        .restorePurchases();
                    if (!context.mounted) return;
                    showAppSnack(context, l10n.proUnlocked);
                  },
                  child: Text(l10n.restorePurchases),
                ),
              ],
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
                    Icon(
                      Icons.verified,
                      color: RideVizPalette.leanLeft,
                      size: 18,
                    ),
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
          SettingsGroup(
            title: l10n.settingsCloudSection,
            help: l10n.syncCloudRidesHelp,
            children: [
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
            ],
          ),
          SettingsGroup(
            title: l10n.labsSectionTitle,
            help: l10n.labsSectionHelp,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.showForceStartArmed, style: _tileTitle),
                subtitle: Text(l10n.showForceStartArmedHelp, style: _tileSub),
                value: ref.watch(forceStartArmedVisibleProvider),
                activeThumbColor: RideVizPalette.leanLeft,
                onChanged: (v) => ref
                    .read(forceStartArmedVisibleProvider.notifier)
                    .setVisible(v),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gps_fixed, color: AppTheme.lineHot),
                title: Text(l10n.gpsTrackPointsLabTile, style: _tileTitle),
                subtitle: Text(l10n.gpsTrackPointsLabHelp, style: _tileSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GpsTrackPointsLabScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppMotoIcon(size: 28, color: AppTheme.line),
                title: Text(l10n.leanLabSettingsTile, style: _tileTitle),
                subtitle: Text(l10n.leanLabSettingsHelp, style: _tileSub),
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
                title: Text(l10n.leanImuLabSettingsTile, style: _tileTitle),
                subtitle: Text(l10n.leanImuLabSettingsHelp, style: _tileSub),
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
                leading: const Icon(
                  Icons.notifications_outlined,
                  color: AppTheme.mist,
                ),
                title: Text(l10n.pushDiagnosticsTitle, style: _tileTitle),
                subtitle: SelectableText(
                  PushDiagnostics.history.isEmpty
                      ? l10n.pushDiagnosticsEmpty
                      : PushDiagnostics.history.reversed.take(5).join('\n'),
                  style: _tileSub,
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
                          showAppSnack(context, l10n.pushDiagnosticsCopied);
                        },
                      ),
              ),
              const AdventureCameraSettingsSection(),
            ],
          ),
          SettingsGroup(
            title: l10n.settingsLegalSection,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.description_outlined,
                  color: AppTheme.line,
                ),
                title: Text(l10n.termsTitle, style: _tileTitle),
                subtitle: Text(l10n.legalOpenInBrowser, style: _tileSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openLegalUrlOrSnack(context, LegalUrls.terms),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppTheme.line,
                ),
                title: Text(l10n.privacyTitle, style: _tileTitle),
                subtitle: Text(l10n.legalOpenInBrowser, style: _tileSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openLegalUrlOrSnack(context, LegalUrls.privacy),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.gavel_outlined, color: AppTheme.line),
                title: Text(l10n.ugcGuidelinesTitle, style: _tileTitle),
                subtitle: Text(l10n.ugcGuidelinesBanner, style: _tileSub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showUgcGuidelinesDialog(context),
              ),
              if (ref.watch(impersonationProvider).staff &&
                  !ref.watch(impersonationProvider).active) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.visibility, color: AppTheme.signal),
                  title: Text(l10n.impersonateTile, style: _tileTitle),
                  subtitle: Text(l10n.impersonateHelp, style: _tileSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ImpersonateScreen(),
                      ),
                    );
                  },
                ),
                const _StaffPartnerCodeTile(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.flag_outlined,
                    color: AppTheme.signal,
                  ),
                  title: Text(l10n.ugcStaffQueueTitle, style: _tileTitle),
                  subtitle: Text(l10n.ugcStaffQueueHelp, style: _tileSub),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StaffReportsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          if (signedIn) accountGroup,
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
      showAppSnackError(context, l10n.partnerCodeInvalid);
      return;
    }
    setState(() => _lastCode = result.code);
    await Clipboard.setData(ClipboardData(text: result.code!));
    if (!mounted) return;
    showAppSnack(context, l10n.partnerCodeCopied(result.code!));
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
