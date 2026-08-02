import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_theme.dart';
import '../rodada_providers.dart';

/// Live pack map. Watching [rodadaLivePublisherProvider] starts GPS publish;
/// leaving this tab disposes the publisher and clears your cloud position.
class RodadaLiveTab extends ConsumerWidget {
  const RodadaLiveTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Activate publisher only while this widget is mounted.
    ref.watch(rodadaLivePublisherProvider(rodadaId));
    final positions = ref.watch(rodadaLivePositionsProvider(rodadaId));
    final stops = ref.watch(rodadaStopsProvider(rodadaId));
    final overview = ref.watch(rodadaOverviewProvider(rodadaId));
    final membership = ref.watch(myRodadaMembershipProvider(rodadaId));

    final meetup = overview.maybeWhen(
      data: (r) => r != null && r.hasMeetup
          ? LatLng(r.meetupLat!, r.meetupLng!)
          : null,
      orElse: () => null,
    );

    return Column(
      children: [
        membership.maybeWhen(
          data: (m) {
            if (m?.shareLive == true) {
              return Material(
                color: AppTheme.line.withValues(alpha: 0.12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.sensors, color: AppTheme.line, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sharing live GPS · stops when you leave this tab',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Material(
              color: AppTheme.asphaltElevated,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Live map is view-only. Enable sharing in Overview.',
                        style: TextStyle(fontSize: 13, color: AppTheme.steel),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await ref.read(rodadaRepositoryProvider).updateMySharing(
                              rodadaId: rodadaId,
                              shareLive: true,
                            );
                        ref.invalidate(myRodadaMembershipProvider(rodadaId));
                      },
                      child: const Text('Share live'),
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        Expanded(
          child: positions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              final stopList = stops.maybeWhen(
                data: (s) => s,
                orElse: () => const [],
              );
              LatLng center = meetup ?? const LatLng(20.67, -103.35);
              if (list.isNotEmpty) {
                center = LatLng(list.first.latitude, list.first.longitude);
              }
              return Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.motoline.motoline',
                      ),
                      if (meetup != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: meetup,
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.flag,
                                color: AppTheme.lineHot,
                              ),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          for (final s in stopList)
                            Marker(
                              point: LatLng(s.latitude, s.longitude),
                              width: 40,
                              height: 40,
                              child: Tooltip(
                                message: s.title,
                                child: const Icon(
                                  Icons.local_gas_station,
                                  color: AppTheme.signal,
                                ),
                              ),
                            ),
                          for (final p in list)
                            Marker(
                              point: LatLng(p.latitude, p.longitude),
                              width: 48,
                              height: 48,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.asphalt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      p.label.split(' ').first,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.line,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.navigation,
                                    color: AppTheme.line,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (list.isEmpty)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Material(
                        color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'No live riders yet. Opt-in riders appear here (~5s).',
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 24,
                    child: membership.maybeWhen(
                      data: (m) {
                        if (m == null || !m.isHost) {
                          return const SizedBox.shrink();
                        }
                        return FloatingActionButton.extended(
                          heroTag: 'rodada_stop',
                          onPressed: () => _addStop(context, ref),
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Stop'),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addStop(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController(text: 'Gas / break');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add stop'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Drop at my GPS'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      await ref.read(rodadaRepositoryProvider).addStop(
            rodadaId: rodadaId,
            title: titleCtrl.text.trim().isEmpty
                ? 'Stop'
                : titleCtrl.text.trim(),
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
      ref.invalidate(rodadaStopsProvider(rodadaId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}
