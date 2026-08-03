import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/app_theme.dart';
import '../rodada_providers.dart';

class RodadaOverviewTab extends ConsumerWidget {
  const RodadaOverviewTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(rodadaOverviewProvider(rodadaId));
    final members = ref.watch(rodadaMembersProvider(rodadaId));
    final mine = ref.watch(myRodadaMembershipProvider(rodadaId));

    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rodada) {
        if (rodada == null) return const SizedBox.shrink();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (rodada.notes != null && rodada.notes!.trim().isNotEmpty) ...[
              Text(
                rodada.notes!,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.mist,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (rodada.hasMeetup) ...[
              Text(
                'Meetup',
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter:
                          LatLng(rodada.meetupLat!, rodada.meetupLng!),
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.motoline.motoline',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point:
                                LatLng(rodada.meetupLat!, rodada.meetupLng!),
                            width: 36,
                            height: 36,
                            child: const Icon(
                              Icons.place,
                              color: AppTheme.signal,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Your sharing',
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Off by default. When on, location pings every 5 minutes for the '
              'whole rodada (retries every 1 minute if a ping fails).',
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
            ),
            mine.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (m) {
                if (m == null) {
                  return const Text('You are not a member.');
                }
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    _RsvpRow(rodadaId: rodadaId, current: m.rsvp),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Share location on route'),
                      subtitle: const Text(
                        'Every 5 min while rodada is open/live',
                      ),
                      value: m.shareLive,
                      onChanged: (v) async {
                        await ref
                            .read(rodadaRepositoryProvider)
                            .updateMySharing(
                              rodadaId: rodadaId,
                              shareLive: v,
                            );
                        ref.invalidate(myRodadaMembershipProvider(rodadaId));
                        ref.invalidate(myRodadasProvider);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Share my track after rides'),
                      value: m.shareTrack,
                      onChanged: (v) async {
                        await ref
                            .read(rodadaRepositoryProvider)
                            .updateMySharing(
                              rodadaId: rodadaId,
                              shareTrack: v,
                            );
                        ref.invalidate(myRodadaMembershipProvider(rodadaId));
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Riders',
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            members.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return const Text('No members yet');
                }
                return Column(
                  children: [
                    for (final m in list)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.asphalt,
                          child: Text(
                            m.label.isNotEmpty ? m.label[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.line),
                          ),
                        ),
                        title: Text(m.label),
                        subtitle: Text(
                          '${m.role} · ${m.rsvp}'
                          '${m.shareLive ? ' · live on' : ''}'
                          '${m.shareTrack ? ' · track on' : ''}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RsvpRow extends ConsumerWidget {
  const _RsvpRow({required this.rodadaId, required this.current});

  final String rodadaId;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = ['going', 'maybe', 'declined'];
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: current == o,
            onSelected: (_) async {
              await ref.read(rodadaRepositoryProvider).updateMySharing(
                    rodadaId: rodadaId,
                    rsvp: o,
                  );
              ref.invalidate(myRodadaMembershipProvider(rodadaId));
              ref.invalidate(rodadaMembersProvider(rodadaId));
            },
          ),
      ],
    );
  }
}
