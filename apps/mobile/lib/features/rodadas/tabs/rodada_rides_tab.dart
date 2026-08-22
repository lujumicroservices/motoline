import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/ride.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../../maps/live_gps_map_mixin.dart';
import '../models/rodada_models.dart';
import '../rodada_providers.dart';

class RodadaRidesTab extends ConsumerWidget {
  const RodadaRidesTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final rides = ref.watch(rodadaRidesProvider(rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.sharedTracksHelp,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _linkLatestRide(context, ref),
                child: Text(l10n.linkMyRide),
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
                return Center(child: Text(l10n.noSharedRidesYet));
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
                      '${r.lineScore != null ? ' · ${l10n.scoreLabel(r.lineScore!)}' : ''}',
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
    final l10n = context.l10n;
    try {
      final rides = await ref.read(ridesListProvider.future);
      final completed =
          rides.where((r) => r.status == RideStatus.completed).toList();
      if (completed.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noCompletedRidesToLink)),
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
          SnackBar(content: Text(l10n.syncRideFirst)),
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
        SnackBar(content: Text(l10n.rideLinkedToRodada)),
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
    final l10n = context.l10n;
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
            return Center(child: Text(l10n.noTrackPoints));
          }
          final center = LatLng(pts.first.lat, pts.first.lng);
          return _RodadaRideTrackMap(center: center, points: pts);
        },
      ),
    );
  }
}

class _RodadaRideTrackMap extends StatefulWidget {
  const _RodadaRideTrackMap({
    required this.center,
    required this.points,
  });

  final LatLng center;
  final List<({double lat, double lng})> points;

  @override
  State<_RodadaRideTrackMap> createState() => _RodadaRideTrackMapState();
}

class _RodadaRideTrackMapState extends State<_RodadaRideTrackMap>
    with LiveGpsMapMixin {
  final MapController _map = MapController();

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rawthrottle.riderlab',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [
                    for (final p in widget.points) LatLng(p.lat, p.lng),
                  ],
                  color: AppTheme.line,
                  strokeWidth: 4,
                ),
              ],
            ),
            liveGpsMapChild(),
          ],
        ),
        myLocationOverlay(_map),
      ],
    );
  }
}
