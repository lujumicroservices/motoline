import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/services/directions_service.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import '../../reel/reel_compose_screen.dart';
import '../../watch/family_circle_screen.dart';
import '../models/rodada_models.dart';
import '../rodada_itinerary.dart';
import '../rodada_itinerary_map.dart';
import '../rodada_providers.dart';

class RodadaOverviewTab extends ConsumerWidget {
  const RodadaOverviewTab({super.key, required this.rodadaId});

  final String rodadaId;

  String _rsvpLabel(AppLocalizations l10n, String rsvp) {
    return switch (rsvp) {
      'going' => l10n.rsvpGoing,
      'maybe' => l10n.rsvpMaybe,
      'declined' => l10n.rsvpDeclined,
      _ => rsvp,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(rodadaOverviewProvider(rodadaId));
    final members = ref.watch(rodadaMembersProvider(rodadaId));
    final mine = ref.watch(myRodadaMembershipProvider(rodadaId));
    final stops = ref.watch(rodadaStopsProvider(rodadaId));

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
            _ItineraryMap(
              rodada: rodada,
              stops: stops.maybeWhen(
                data: (s) => s,
                orElse: () => const <RodadaStop>[],
              ),
            ),
            Text(
              l10n.yourSharing,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sharingDefaultsHelp,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppTheme.asphaltElevated,
              child: ListTile(
                leading: const Icon(Icons.favorite, color: AppTheme.lineHot),
                title: Text(l10n.familyRodadaTipTitle),
                subtitle: Text(l10n.familyRodadaTipBody),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const FamilyCircleScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.asphaltElevated,
              child: ListTile(
                leading: const Icon(
                  Icons.movie_creation_outlined,
                  color: AppTheme.signal,
                ),
                title: Text(l10n.reelGenerate),
                subtitle: Text(l10n.reelOverviewCta),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openReel(context, ref),
              ),
            ),
            mine.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (m) {
                if (m == null) {
                  return Text(l10n.notRodadaMember);
                }
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    _RsvpRow(rodadaId: rodadaId, current: m.rsvp),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.shareLocationOnRoute),
                      subtitle: Text(l10n.shareLocationEvery5Min),
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
                      title: Text(l10n.shareTrackAfterRides),
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
              l10n.rodadaRiders,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            members.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(l10n.noMembersYet);
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
                          '${m.role} · ${_rsvpLabel(l10n, m.rsvp)}'
                          '${m.shareLive ? ' · ${l10n.memberLiveOn}' : ''}'
                          '${m.shareTrack ? ' · ${l10n.memberTrackOn}' : ''}',
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

  Future<void> _openReel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final repo = ref.read(rodadaRepositoryProvider);
      final me = repo.currentUserId;
      final rides = await ref.read(rodadaRidesProvider(rodadaId).future);
      final mine = rides.where((r) => me == null || r.userId == me).toList();
      String? rideId =
          mine.isNotEmpty && mine.first.localId.isNotEmpty ? mine.first.localId : null;
      if (rideId == null) {
        final local = await ref.read(ridesListProvider.future);
        final completed = local.where((r) => r.status.name == 'completed').toList();
        rideId = completed.isEmpty ? null : completed.first.id;
      }
      if (rideId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noCompletedRidesToLink)),
        );
        return;
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReelComposeScreen(
            rideId: rideId!,
            rodadaId: rodadaId,
            replaceWithRideDetail: false,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _ItineraryMap extends StatelessWidget {
  const _ItineraryMap({required this.rodada, required this.stops});

  final RodadaSummary rodada;
  final List<RodadaStop> stops;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = rodada.hasMeetup
        ? LatLng(rodada.meetupLat!, rodada.meetupLng!)
        : null;
    final finish = rodada.hasFinish
        ? LatLng(rodada.finishLat!, rodada.finishLng!)
        : null;
    final pins = rodadaItineraryLine(
      start: start,
      stops: [for (final s in stops) LatLng(s.latitude, s.longitude)],
      finish: finish,
    );
    final routed = rodada.decodedRoute;
    final line = rodadaDisplayLine(pins: pins, routed: routed);
    if (line.isEmpty) return const SizedBox.shrink();
    final bounds = rodadaItineraryBounds(line);
    final km = rodada.routeDistanceM;
    final eta = rodada.routeDurationS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.rodadaItinerary,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        if (km != null && km > 0 && eta != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.routeSummaryKmEta(
              formatRouteDistance(km),
              formatRouteEta(eta),
            ),
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: line.first,
                initialZoom: 13,
                initialCameraFit: bounds == null
                    ? null
                    : CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(28),
                        maxZoom: 14,
                      ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                ...rodadaItineraryMapLayers(
                  start: start,
                  finish: finish,
                  routedLine: routed.length >= 2 ? routed : null,
                  stops: [
                    for (final s in stops)
                      RodadaItineraryStopPin(
                        point: LatLng(s.latitude, s.longitude),
                        title: s.title,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RsvpRow extends ConsumerWidget {
  const _RsvpRow({required this.rodadaId, required this.current});

  final String rodadaId;
  final String current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    const options = ['going', 'maybe', 'declined'];
    String labelFor(String o) => switch (o) {
          'going' => l10n.rsvpGoing,
          'maybe' => l10n.rsvpMaybe,
          'declined' => l10n.rsvpDeclined,
          _ => o,
        };
    return Wrap(
      spacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelFor(o)),
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
