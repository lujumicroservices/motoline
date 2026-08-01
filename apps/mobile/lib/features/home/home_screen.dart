import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/ride.dart';
import '../../core/models/route_circuit.dart';
import '../../core/models/route_loop.dart';
import '../../core/services/ride_recorder.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/locale_provider.dart';
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
import '../ride_detail/ride_detail_screen.dart';
import '../routes/routes_screen.dart';
import 'update_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(ridesListProvider);
    final incompleteAsync = ref.watch(incompleteRideProvider);
    final updateAsync = ref.watch(appUpdateCheckProvider);
    final locale = ref.watch(localeProvider);
    final armed = ref.watch(armedStateProvider);

    ref.listen(autoStartEventsProvider, (previous, next) {
      next.whenData((ride) {
        unawaited(_openAutoStartedRide(context, ref, ride));
      });
    });

    return AdventureCameraLifecycleBinder(
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
                      IconButton(
                        tooltip: l10n.routesTitle,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const RoutesScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.route_outlined, size: 20),
                        color: AppTheme.mist,
                      ),
                      IconButton(
                        tooltip: l10n.friends,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const FriendsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.group_outlined, size: 20),
                        color: AppTheme.mist,
                      ),
                      IconButton(
                        tooltip: l10n.language,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed: () =>
                            ref.read(localeProvider.notifier).toggle(),
                        icon: Text(
                          locale.languageCode.toUpperCase(),
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: AppTheme.mist,
                          ),
                        ),
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
            if (armed) const _ArmedBanner(),
            ridesAsync.when(
              data: (rides) {
                final summary = FleetSummary.fromRides(rides);
                if (summary.rideCount == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: _SeasonStrip(summary: summary),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                l10n.yourRides,
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ridesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load rides: $e')),
                data: (rides) {
                  final completed = rides
                      .where((r) => r.status != RideStatus.recording)
                      .toList();
                  if (completed.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: completed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ride = completed[index];
                      return _RideTile(
                        ride: ride,
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
              armed: armed,
              onStart: () {
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
                final notifier = ref.read(armedStateProvider.notifier);
                if (armed) {
                  notifier.disarm();
                  return;
                }
                try {
                  final routeId = await _resolveArmRouteId(ref);
                  await notifier.arm(routeId: routeId);
                  if (!context.mounted) return;
                  if (routeId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.armAutoNoRouteHint)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.armAutoRouteArmed)),
                    );
                  }
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
    );
  }
}

Future<void> _openAutoStartedRide(
  BuildContext context,
  WidgetRef ref,
  Ride ride,
) async {
  RouteCircuit? route;
  RouteLoop? loop;
  final routeId = ride.routeId;
  if (routeId != null && routeId.isNotEmpty) {
    final db = ref.read(rideDatabaseProvider);
    route = await db.getRoute(routeId);
    loop = await db.getPrimaryLoop(routeId);
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ActiveRideScreen(
        autoStart: false,
        mode: route != null ? ActiveRideMode.loop : ActiveRideMode.normal,
        route: route,
        loop: loop,
      ),
    ),
  );
  ref.invalidate(ridesListProvider);
  ref.invalidate(incompleteRideProvider);
  if (routeId != null) {
    ref.invalidate(ridesForRouteProvider(routeId));
  }
}

/// Prefer last armed/started route; else newest local circuit.
Future<String?> _resolveArmRouteId(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final preferred =
      prefs.getString(RideRecorder.preferredArmRoutePrefKey)?.trim();
  final db = ref.read(rideDatabaseProvider);
  if (preferred != null && preferred.isNotEmpty) {
    final existing = await db.getRoute(preferred);
    if (existing != null) return preferred;
  }
  final routes = await db.listRoutes();
  if (routes.isEmpty) return null;
  return routes.first.id;
}

/// If arm auto-started while the screen was locked, open the active ride HUD
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
    _opening = true;
    try {
      await _openAutoStartedRide(context, ref, ride);
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
                child: FilledButton.icon(
                  onPressed: onStart,
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
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
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
                        ? Icons.motion_photos_off_outlined
                        : Icons.motion_photos_auto_outlined,
                    size: 26,
                  ),
                  label: Text(
                    armed ? l10n.disarmAutoRide : l10n.armAutoRide,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
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

class _ArmedBanner extends StatelessWidget {
  const _ArmedBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          const Icon(Icons.motion_photos_auto, color: AppTheme.lineHot),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.waitingForMotion,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.armedBannerBody,
                  style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                ),
              ],
            ),
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
                      ref.read(rideSyncServiceProvider).syncRide(completed.id),
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
  });

  final Ride ride;
  final VoidCallback onDeleted;

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

    return Material(
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
                  abandoned ? Icons.link_off : Icons.route,
                  color: abandoned ? AppTheme.steel : AppTheme.line,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      abandoned
                          ? 'Discarded'
                          : '${ride.distanceKm.toStringAsFixed(2)} km · '
                              '${formatDuration(ride.duration)}'
                              '${ride.maxSpeedKmh == null ? '' : ' · max ${ride.maxSpeedKmh!.toStringAsFixed(0)} km/h'}'
                              '${ride.maxLeanDegrees == null ? '' : ' · lean ${ride.maxLeanDegrees!.toStringAsFixed(0)}°'}',
                      style: const TextStyle(
                        color: AppTheme.steel,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
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
            'PERFORMANCE',
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
                  label: 'Rides',
                  value: '${summary.rideCount}',
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: 'Distance',
                  value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: 'Top speed',
                  value: summary.bestMaxSpeedKmh == null
                      ? '--'
                      : summary.bestMaxSpeedKmh!.toStringAsFixed(0),
                ),
              ),
              Expanded(
                child: _GarageStat(
                  label: 'Peak lean',
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
