import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/utils/geo_utils.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import 'pilot_line_map.dart';

class RideDetailScreen extends ConsumerWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(rideProvider(rideId));
    final pointsAsync = ref.watch(ridePointsProvider(rideId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilot line'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ride) {
          if (ride == null) {
            return const Center(child: Text('Ride not found'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().add_jm().format(ride.startedAt),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ChipStat(
                          label: 'Distance',
                          value: '${ride.distanceKm.toStringAsFixed(2)} km',
                        ),
                        _ChipStat(
                          label: 'Duration',
                          value: formatDuration(ride.duration),
                        ),
                        _ChipStat(
                          label: 'Max',
                          value: ride.maxSpeedKmh == null
                              ? '--'
                              : '${ride.maxSpeedKmh!.toStringAsFixed(0)} km/h',
                        ),
                        _ChipStat(
                          label: 'Avg',
                          value: ride.avgSpeedKmh == null
                              ? '--'
                              : '${ride.avgSpeedKmh!.toStringAsFixed(0)} km/h',
                        ),
                        _ChipStat(
                          label: 'Points',
                          value: '${ride.pointCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Teal = slower · Amber = mid · Orange = faster. '
                      'Gaps in GPS show as breaks in the line.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.steel,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: pointsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (points) => PilotLineMap(points: points),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChipStat extends StatelessWidget {
  const _ChipStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: AppTheme.steel,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
