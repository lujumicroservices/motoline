import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/ride.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../models/rodada_models.dart';
import '../rodada_providers.dart';

class RodadaRidesTab extends ConsumerWidget {
  const RodadaRidesTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rides = ref.watch(rodadaRidesProvider(rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Shared tracks from members who opted in. Dense GPS stays on each phone.',
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _linkLatestRide(context, ref),
                child: const Text('Link my ride'),
              ),
            ],
          ),
        ),
        Expanded(
          child: rides.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No shared rides yet'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ListTile(
                    title: Text(r.riderLabel),
                    subtitle: Text(
                      '${r.distanceKm.toStringAsFixed(1)} km'
                      '${r.maxSpeedKmh != null ? ' · ${r.maxSpeedKmh!.toStringAsFixed(0)} km/h' : ''}'
                      '${r.lineScore != null ? ' · score ${r.lineScore}' : ''}',
                    ),
                    trailing: const Icon(Icons.map_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _RodadaRideTrackScreen(ride: r),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _linkLatestRide(BuildContext context, WidgetRef ref) async {
    try {
      final rides = await ref.read(ridesListProvider.future);
      final completed =
          rides.where((r) => r.status == RideStatus.completed).toList();
      if (completed.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No completed rides to link')),
        );
        return;
      }
      final local = completed.first;
      await ref.read(rideSyncServiceProvider).syncRide(local.id);
      final cloudId = await ref
          .read(rodadaRepositoryProvider)
          .cloudRideIdForLocal(local.id);
      if (cloudId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync the ride first, then try again')),
        );
        return;
      }
      await ref.read(rodadaRepositoryProvider).linkRideToRodada(
            cloudRideId: cloudId,
            rodadaId: rodadaId,
          );
      ref.invalidate(rodadaRidesProvider(rodadaId));
      ref.invalidate(myRodadaMembershipProvider(rodadaId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ride linked to this rodada')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

/// Downsampled track — provider autoDisposes when this screen pops.
class _RodadaRideTrackScreen extends ConsumerWidget {
  const _RodadaRideTrackScreen({required this.ride});

  final RodadaRideSummary ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(rodadaRideTrackProvider(ride.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ride.riderLabel,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: track.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pts) {
          if (pts.isEmpty) {
            return const Center(child: Text('No track points'));
          }
          final center = LatLng(pts.first.lat, pts.first.lng);
          return FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.motoline.motoline',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [for (final p in pts) LatLng(p.lat, p.lng)],
                    color: AppTheme.line,
                    strokeWidth: 4,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
