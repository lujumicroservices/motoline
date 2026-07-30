import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../ride_detail/pilot_line_map.dart';
import '../ride_detail/ride_detail_screen.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(activeRideProvider);
    final recorder = ref.watch(rideRecorderProvider);
    final ride = recorder.activeRide;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recording'),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.signal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.signal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: GoogleFonts.spaceGrotesk(
                          color: AppTheme.signal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: snapshotAsync.when(
          loading: () => _body(
            context,
            distanceKm: ride?.distanceKm ?? 0,
            duration: ride?.duration ?? Duration.zero,
            points: const <TrackPoint>[],
            pointCount: ride?.pointCount ?? 0,
            speedKmh: null,
          ),
          error: (e, _) => Center(child: Text('$e')),
          data: (snap) {
            final r = snap?.ride ?? ride;
            return _body(
              context,
              distanceKm: r?.distanceKm ?? 0,
              duration: r?.duration ?? Duration.zero,
              points: snap?.points ?? const <TrackPoint>[],
              pointCount: r?.pointCount ?? 0,
              speedKmh: snap?.lastPoint?.speedKmh,
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required double distanceKm,
    required Duration duration,
    required List<TrackPoint> points,
    required int pointCount,
    required double? speedKmh,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Text(
            'Keep the phone mounted. Do not interact while riding.',
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Distance',
                  value: distanceKm.toStringAsFixed(2),
                  unit: 'km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Time',
                  value: formatDuration(duration),
                  unit: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Speed',
                  value: speedKmh == null
                      ? '--'
                      : speedKmh.toStringAsFixed(0),
                  unit: 'km/h',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Points',
                  value: '$pointCount',
                  unit: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: PilotLineMap(
              points: points,
              interactive: false,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.signal,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => _stop(context),
            child: const Text('End ride'),
          ),
        ),
      ],
    );
  }

  Future<void> _stop(BuildContext context) async {
    final recorder = ref.read(rideRecorderProvider);
    try {
      final ride = await recorder.stop();
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RideDetailScreen(rideId: ride.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              color: AppTheme.steel,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
