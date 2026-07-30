import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/ride.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../ride_active/active_ride_screen.dart';
import '../ride_detail/ride_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesListProvider);
    final incompleteAsync = ref.watch(incompleteRideProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CornerIQ',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: AppTheme.mist,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record the line you rode. Scrub it. Improve every corner.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppTheme.steel,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            incompleteAsync.when(
              data: (ride) {
                if (ride == null) return const SizedBox.shrink();
                return _RecoveryBanner(ride: ride);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: FilledButton(
                onPressed: () => _startRide(context, ref),
                child: const Text('Start ride'),
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
                'Your rides',
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

  Future<void> _startRide(BuildContext context, WidgetRef ref) async {
    final recorder = ref.read(rideRecorderProvider);
    try {
      await recorder.start();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ActiveRideScreen()),
      );
      ref.invalidate(ridesListProvider);
      ref.invalidate(incompleteRideProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _RecoveryBanner extends ConsumerWidget {
  const _RecoveryBanner({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            'Unfinished ride found',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Started ${DateFormat.MMMd().add_jm().format(ride.startedAt)}. '
            'Finalize it to keep the line, or discard.',
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
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final completed = await ref
                        .read(rideRecorderProvider)
                        .finalizeRecovered(ride.id);
                    ref.invalidate(ridesListProvider);
                    ref.invalidate(incompleteRideProvider);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RideDetailScreen(rideId: completed.id),
                      ),
                    );
                  },
                  child: const Text('Keep line'),
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
            'No rides yet',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a ride and CornerIQ will draw the exact line you took on the street.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.steel, height: 1.4),
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
