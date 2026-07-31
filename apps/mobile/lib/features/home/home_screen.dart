import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/ride.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/locale_provider.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../providers/update_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/brand_mark.dart';
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
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ActiveRideScreen(autoStart: false),
          ),
        ).then((_) {
          ref.invalidate(ridesListProvider);
          ref.invalidate(incompleteRideProvider);
        });
      });
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const RiderLabMark(size: BrandMarkSize.hero),
                        const SizedBox(height: 8),
                        Text(
                          l10n.tagline,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: AppTheme.steel,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.routesTitle,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RoutesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.route_outlined),
                    color: AppTheme.mist,
                  ),
                  IconButton(
                    tooltip: l10n.friends,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const FriendsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.group_outlined),
                    color: AppTheme.mist,
                  ),
                  IconButton(
                    tooltip: l10n.language,
                    onPressed: () => ref.read(localeProvider.notifier).toggle(),
                    icon: Text(
                      locale.languageCode.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.mist,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.checkUpdates,
                    onPressed: () => promptManualUpdateCheck(context, ref),
                    icon: const Icon(Icons.system_update_alt_outlined),
                    color: AppTheme.steel,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ActiveRideScreen(),
                    ),
                  ).then((_) {
                    ref.invalidate(ridesListProvider);
                    ref.invalidate(incompleteRideProvider);
                  });
                },
                child: Text(l10n.startRide),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final notifier = ref.read(armedStateProvider.notifier);
                        if (armed) {
                          notifier.disarm();
                        } else {
                          try {
                            await notifier.arm();
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      style: armed
                          ? OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.lineHot,
                              side: const BorderSide(color: AppTheme.lineHot),
                            )
                          : null,
                      child: Text(
                        armed ? l10n.disarmAutoRide : l10n.armAutoRide,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ActiveRideScreen(
                              mode: ActiveRideMode.loop,
                            ),
                          ),
                        ).then((_) {
                          ref.invalidate(ridesListProvider);
                          ref.invalidate(incompleteRideProvider);
                        });
                      },
                      child: Text(l10n.loopMode),
                    ),
                  ),
                ],
              ),
            ),
            ridesAsync.when(
              data: (rides) {
                final summary = FleetSummary.fromRides(rides);
                if (summary.rideCount == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: _SeasonStrip(summary: summary),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                l10n.yourRides,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    itemCount: completed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final ride = completed[index];
                      return _RideTile(ride: ride);
                    },
                  );
                },
              ),
            ),
          ],
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
                  style: GoogleFonts.spaceGrotesk(
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
            style: GoogleFonts.spaceGrotesk(
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

class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.MMMd().add_jm().format(ride.startedAt);
    final abandoned = ride.status == RideStatus.abandoned;

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
                );
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
                      style: GoogleFonts.spaceGrotesk(
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
              if (!abandoned)
                const Icon(Icons.chevron_right, color: AppTheme.steel),
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
            style: GoogleFonts.spaceGrotesk(
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF262B30), Color(0xFF1B1F23)],
        ),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR GARAGE',
            style: GoogleFonts.outfit(
              fontSize: 11,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w600,
              color: AppTheme.line,
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
          style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.steel),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
