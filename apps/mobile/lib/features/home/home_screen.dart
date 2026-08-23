import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/demo_ids.dart';
import '../../core/features.dart';
import '../../core/auth/impersonation_controller.dart';
import '../../core/models/ride.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../providers/update_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/pro_upsell.dart';
import '../../widgets/rider_alias_chip.dart';
import '../adventure_camera/widgets/adventure_camera_lifecycle_binder.dart';
import '../friends/friends_screen.dart';
import '../ride_active/active_ride_screen.dart';
import '../ride_active/armed_session_flow.dart';
import '../ride_active/armed_session_nav.dart';
import '../ride_active/widgets/upright_freeze_sheet.dart';
import '../ride_detail/ride_detail_screen.dart';
import '../ride_detail/ride_rename.dart';
import '../rodadas/models/rodada_models.dart';
import '../rodadas/rodada_detail_screen.dart';
import '../rodadas/rodada_providers.dart';
import '../rodadas/rodada_route_share_binder.dart';
import '../rodadas/rodadas_screen.dart';
import '../routes/routes_screen.dart';
import 'home_nav_icons.dart';
import 'update_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(ridesListProvider);
    final incompleteAsync = ref.watch(incompleteRideProvider);
    final updateAsync = ref.watch(appUpdateCheckProvider);
    final armed = ref.watch(armedStateProvider);
    final recording = ref.watch(rideRecorderProvider).isRecording;
    final sessionLive = armed || recording;

    ref.listen(autoStartEventsProvider, (previous, next) {
      next.whenData((_) {
        openArmedSessionAfterAutoStart(context, ref);
      });
    });

    return RodadaRouteShareBinder(
      child: AdventureCameraLifecycleBinder(
      child: Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ArmAutoResumeOpener(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RiderLabMark(
                          size: BrandMarkSize.title,
                          showAccentBar: true,
                          showAttribution: true,
                          attribution: l10n.byRawThrottle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const RiderProfileButton(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.tagline,
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            color: AppTheme.steel,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (AppFeatures.routesEnabled)
                        HomeNavIconButton(
                          tooltip: l10n.routesTitle,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RoutesScreen(),
                              ),
                            );
                          },
                          asset: AppAssetIcon.routes,
                        ),
                      HomeNavIconButton(
                        tooltip: l10n.rodadasTitle,
                        semanticId: DemoIds.navRodadas,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RodadasScreen(),
                            ),
                          );
                        },
                        asset: AppAssetIcon.rodadas,
                      ),
                      HomeNavIconButton(
                        tooltip: l10n.friends,
                        semanticId: DemoIds.navFriends,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FriendsScreen(),
                            ),
                          );
                        },
                        icon: Icons.people_outline,
                      ),
                      const UpdateCheckIconButton(),
                    ],
                  ),
                ],
              ),
            ),
            updateAsync.when(
              data: (update) {
                if (update == null) return const SizedBox.shrink();
                final dismissed = ref.watch(dismissedUpdateTagProvider);
                if (dismissed == update.tagName) {
                  return const SizedBox.shrink();
                }
                return UpdateAvailableBanner(update: update);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            incompleteAsync.when(
              data: (ride) {
                if (ride == null) return const SizedBox.shrink();
                return _RecoveryBanner(ride: ride);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            if (sessionLive) const _ArmedBanner(),
            ridesAsync.when(
              data: (rides) {
                final summary = FleetSummary.fromRides(rides);
                if (summary.rideCount == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _SeasonStrip(summary: summary),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const _RodadaHomeCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.yourRides,
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ridesAsync.maybeWhen(
                    data: (rides) {
                      final untitled = rides
                          .where(
                            (r) =>
                                r.status == RideStatus.completed &&
                                (r.title == null || r.title!.trim().isEmpty) &&
                                r.pointCount >= 2,
                          )
                          .isNotEmpty;
                      final naming = ref.watch(rideTitleNamingProvider);
                      if (!untitled && !naming.running) {
                        return const SizedBox.shrink();
                      }
                      if (naming.running) {
                        return Text(
                          l10n.namingRidesProgress(naming.done, naming.total),
                          style: const TextStyle(
                            color: AppTheme.steel,
                            fontSize: 12,
                          ),
                        );
                      }
                      return TextButton.icon(
                        onPressed: () async {
                          final count = await ref
                              .read(rideTitleNamingProvider.notifier)
                              .nameAll();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                count > 0
                                    ? l10n.namedRidesDone(count)
                                    : l10n.nameRidesFromMapHelp,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.place_outlined, size: 18),
                        label: Text(l10n.nameRidesFromMap),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.line,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ridesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.couldNotLoadRides('$e'))),
                data: (rides) {
                  final completed = rides
                      .where((r) => r.status != RideStatus.recording)
                      .toList();
                  if (completed.isEmpty) {
                    return const _EmptyState();
                  }
                  final rows = _garageRowsByMonth(completed, l10n.localeName);
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: rows.length,
                    separatorBuilder: (_, i) {
                      final next = i + 1 < rows.length ? rows[i + 1] : null;
                      if (next is _GarageMonthHeader) {
                        return const SizedBox(height: 4);
                      }
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is _GarageMonthHeader) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : 10,
                            bottom: 4,
                          ),
                          child: Text(
                            row.label,
                            style: GoogleFonts.exo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppTheme.steel,
                            ),
                          ),
                        );
                      }
                      final ride = (row as _GarageRideRow).ride;
                      return _RideTile(
                        ride: ride,
                        demoId: ride.status == RideStatus.abandoned
                            ? null
                            : DemoIds.rideTile,
                        onDeleted: () {
                          ref.invalidate(ridesListProvider);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            _HomeActionDock(
              armed: sessionLive,
              onStart: () {
                if (ref.read(impersonationProvider).active) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.impersonateNoRide)),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ActiveRideScreen(autoStart: false),
                  ),
                ).then((_) {
                  ref.invalidate(ridesListProvider);
                  ref.invalidate(incompleteRideProvider);
                });
              },
              onArmToggle: () async {
                if (ref.read(impersonationProvider).active) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.impersonateNoRide)),
                  );
                  return;
                }
                if (sessionLive) {
                  ensureArmedSessionHub(context, ref);
                  return;
                }
                try {
                  final ok = await freezeThenArm(context, ref);
                  if (!ok || !context.mounted) return;
                  ref.read(armedSessionNavProvider.notifier).reset();
                  ensureArmedSessionHub(context, ref);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.armAutoNoRouteHint)),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
            ),
            FreeAdBanner(
              onUpgrade: () => showProUpsellSheet(context, ref),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}

sealed class _GarageRow {
  const _GarageRow();
}

class _GarageMonthHeader extends _GarageRow {
  const _GarageMonthHeader(this.label);
  final String label;
}

class _GarageRideRow extends _GarageRow {
  const _GarageRideRow(this.ride);
  final Ride ride;
}

List<_GarageRow> _garageRowsByMonth(List<Ride> rides, String localeName) {
  final rows = <_GarageRow>[];
  String? lastKey;
  final fmt = DateFormat.yMMMM(localeName);
  for (final ride in rides) {
    final key = '${ride.startedAt.year}-${ride.startedAt.month}';
    if (key != lastKey) {
      lastKey = key;
      final raw = fmt.format(ride.startedAt);
      final label = raw.isEmpty
          ? key
          : '${raw[0].toUpperCase()}${raw.substring(1)}';
      rows.add(_GarageMonthHeader(label));
    }
    rows.add(_GarageRideRow(ride));
  }
  return rows;
}

/// Current live rodada, else the soonest upcoming/open one — never a list.
RodadaSummary? _pickHomeRodada(List<RodadaSummary> list) {
  final now = DateTime.now();
  for (final r in list) {
    if (r.isLive) return r;
  }
  for (final r in list) {
    if (r.isPendingInvite) return r;
  }

  final candidates = list.where((r) => !r.isEnded).toList();
  if (candidates.isEmpty) return null;

  final dated = candidates.where((r) => r.startsAt != null).toList()
    ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));

  // Nearest upcoming (or started within the last 12h — still "current").
  final horizon = now.subtract(const Duration(hours: 12));
  for (final r in dated) {
    if (!r.startsAt!.isBefore(horizon)) return r;
  }

  // Open/draft without a start time.
  for (final r in candidates) {
    if (r.startsAt == null && (r.status == 'open' || r.status == 'draft')) {
      return r;
    }
  }
  return null;
}

/// If arm auto-started while the screen was locked, open the session hub
/// when the user returns (broadcast stream events can be missed while paused).
class _ArmAutoResumeOpener extends ConsumerStatefulWidget {
  const _ArmAutoResumeOpener();

  @override
  ConsumerState<_ArmAutoResumeOpener> createState() =>
      _ArmAutoResumeOpenerState();
}

class _ArmAutoResumeOpenerState extends ConsumerState<_ArmAutoResumeOpener>
    with WidgetsBindingObserver {
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_openIfRecording());
    }
  }

  Future<void> _openIfRecording() async {
    if (_opening || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final recorder = ref.read(rideRecorderProvider);
    final ride = recorder.activeRide;
    if (!recorder.isRecording || ride == null) return;
    final nav = ref.read(armedSessionNavProvider);
    _opening = true;
    try {
      if (shouldResumeHubFromHome(
        isRecording: true,
        hubOnStack: nav.hubOnStack,
      )) {
        ensureArmedSessionHub(context, ref);
      }
      if (shouldAutoPushHud(nav, isRecording: true)) {
        openArmedRecordingHud(context, ref);
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _HomeActionDock extends StatelessWidget {
  const _HomeActionDock({
    required this.armed,
    required this.onStart,
    required this.onArmToggle,
  });

  final bool armed;
  final VoidCallback onStart;
  final VoidCallback onArmToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final glove = ButtonStyle(
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      minimumSize: const WidgetStatePropertyAll(Size(0, 72)),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: WidgetStatePropertyAll(
        GoogleFonts.exo2(fontWeight: FontWeight.w800, fontSize: 18),
      ),
    );

    return Material(
      color: AppTheme.asphaltElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: DemoTarget(
                  id: DemoIds.ctaStart,
                  child: FilledButton.icon(
                  onPressed: armed ? null : onStart,
                  style: glove.copyWith(
                    backgroundColor:
                        const WidgetStatePropertyAll(AppTheme.mist),
                    foregroundColor:
                        const WidgetStatePropertyAll(AppTheme.asphalt),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 32),
                  label: Text(l10n.startRide),
                ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DemoTarget(
                  id: DemoIds.ctaArm,
                  child: OutlinedButton.icon(
                  onPressed: onArmToggle,
                  style: glove.copyWith(
                    foregroundColor: WidgetStatePropertyAll(
                      armed ? AppTheme.lineHot : AppTheme.mist,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(
                        width: 2,
                        color: armed ? AppTheme.lineHot : AppTheme.steel,
                      ),
                    ),
                  ),
                  icon: Icon(
                    armed
                        ? Icons.route_outlined
                        : Icons.motion_photos_auto_outlined,
                    size: 26,
                  ),
                  label: Text(
                    armed ? l10n.armedSessionOpen : l10n.armAutoRide,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight home teaser — at most one rodada (live or nearest upcoming).
class _RodadaHomeCard extends ConsumerWidget {
  const _RodadaHomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(myRodadasProvider);
    return async.maybeWhen(
      data: (list) {
        final highlight = _pickHomeRodada(list);
        if (highlight == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Material(
            color: AppTheme.asphaltElevated,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RodadaDetailScreen(rodadaId: highlight.id),
                  ),
                );
                ref.invalidate(myRodadasProvider);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    AppAssetIcon(
                      asset: AppAssetIcon.rodadas,
                      size: 36,
                      color: highlight.isLive
                          ? AppTheme.line
                          : AppTheme.mist,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highlight.title,
                            style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${highlight.isPendingInvite ? l10n.rodadaInviteChip : highlight.status.toUpperCase()} · ${l10n.rodadaRidersCount(highlight.memberCount)}'
                            '${highlight.destination != null ? ' · ${highlight.destination}' : ''}',
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.steel),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ArmedBanner extends ConsumerWidget {
  const _ArmedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final recording = ref.watch(rideRecorderProvider).isRecording;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineHot.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            recording ? Icons.fiber_manual_record : Icons.motion_photos_auto,
            color: AppTheme.lineHot,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording ? l10n.recording : l10n.waitingForMotion,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recording
                      ? l10n.armedSessionLiveHelp
                      : l10n.armedBannerBody,
                  style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => ensureArmedSessionHub(context, ref),
            child: Text(l10n.armedSessionOpen),
          ),
        ],
      ),
    );
  }
}

class _RecoveryBanner extends ConsumerWidget {
  const _RecoveryBanner({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineHot.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.unfinishedRide,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.unfinishedRideBody(
              DateFormat.MMMd().add_jm().format(ride.startedAt),
            ),
            style: const TextStyle(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(rideRecorderProvider)
                        .abandonRecovered(ride.id);
                    ref.invalidate(ridesListProvider);
                    ref.invalidate(incompleteRideProvider);
                  },
                  child: Text(l10n.discard),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final completed = await ref
                        .read(rideRecorderProvider)
                        .finalizeRecovered(ride.id);
                    unawaited(
                      enqueueAndDrainRideSync(
                        ref.read(syncOutboxServiceProvider),
                        completed.id,
                      ),
                    );
                    ref.invalidate(ridesListProvider);
                    ref.invalidate(incompleteRideProvider);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RideDetailScreen(rideId: completed.id),
                      ),
                    );
                  },
                  child: Text(l10n.keepLine),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RideTile extends ConsumerWidget {
  const _RideTile({
    required this.ride,
    required this.onDeleted,
    this.demoId,
  });

  final Ride ride;
  final VoidCallback onDeleted;
  final String? demoId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRide),
        content: Text(l10n.deleteRideBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.notNow),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.signal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(rideSyncServiceProvider).deleteRideEverywhere(ride.id);
    if (ride.routeId != null) {
      ref.invalidate(ridesForRouteProvider(ride.routeId!));
    }
    onDeleted();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.rideDeleted)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateFormat.MMMd().add_jm().format(ride.startedAt);
    final abandoned = ride.status == RideStatus.abandoned;
    final l10n = context.l10n;

    final tile = Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: abandoned
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RideDetailScreen(rideId: ride.id),
                  ),
                ).then((_) => onDeleted());
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.asphalt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  abandoned ? Icons.link_off : Icons.two_wheeler,
                  color: abandoned ? AppTheme.steel : AppTheme.line,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      abandoned
                          ? date
                          : ride.displayTitle(
                              dateFormat: (_) => l10n.rideUntitledHint,
                            ),
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      abandoned
                          ? l10n.rideDiscarded
                          : [
                              date,
                              '${ride.distanceKm.toStringAsFixed(2)} km',
                              formatDuration(ride.duration),
                              if (ride.maxSpeedKmh != null)
                                'max ${ride.maxSpeedKmh!.toStringAsFixed(0)} km/h',
                              if (ride.maxLeanDegrees != null)
                                'lean ${ride.maxLeanDegrees!.toStringAsFixed(0)}°',
                            ].join(' · '),
                      style: const TextStyle(
                        color: AppTheme.steel,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!abandoned)
                IconButton(
                  tooltip: l10n.renameRide,
                  onPressed: () => showRideRenameDialog(context, ref, ride),
                  icon: const Icon(Icons.edit_outlined),
                  color: AppTheme.mist,
                ),
              IconButton(
                tooltip: l10n.deleteRide,
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.signal,
              ),
            ],
          ),
        ),
      ),
    );
    final id = demoId;
    if (id == null) return tile;
    return DemoTarget(id: id, child: tile);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 56, color: AppTheme.steel.withValues(alpha: 0.7)),
          const SizedBox(height: 16),
          Text(
            context.l10n.emptyRidesTitle,
            style: GoogleFonts.exo2(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.emptyRidesBody,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.steel, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SeasonStrip extends StatelessWidget {
  const _SeasonStrip({required this.summary});

  final FleetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.asphaltElevated,
            Color.lerp(AppTheme.asphalt, AppTheme.signal, 0.12)!,
            Color.lerp(AppTheme.asphaltElevated, AppTheme.line, 0.08)!,
          ],
        ),
        border: Border.all(color: AppTheme.signal.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.performanceLabel,
            style: GoogleFonts.exo2(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: AppTheme.signal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _GarageStat(
                  label: l10n.statRides,
                  value: '${summary.rideCount}',
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: l10n.statDistance,
                  value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: l10n.statTopSpeed,
                  value: summary.bestMaxSpeedKmh == null
                      ? '--'
                      : summary.bestMaxSpeedKmh!.toStringAsFixed(0),
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: l10n.statPeakLean,
                  value: summary.bestMaxLean == null
                      ? '--'
                      : '${summary.bestMaxLean!.toStringAsFixed(0)}°',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GarageStat extends StatelessWidget {
  const _GarageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(fontSize: 11, color: AppTheme.steel),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.mist,
          ),
        ),
      ],
    );
  }
}
