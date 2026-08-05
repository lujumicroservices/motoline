import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/analytics/track_segment_align.dart';
import '../../core/models/cloud_models.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import 'compare_widgets.dart';

/// Metrics-first compare: your local ride vs a peer cloud ride in the same area.
class RideCompareScreen extends ConsumerStatefulWidget {
  const RideCompareScreen({
    super.key,
    required this.localRideId,
    this.initialPeer,
  });

  final String localRideId;
  final CloudRideSummary? initialPeer;

  @override
  ConsumerState<RideCompareScreen> createState() => _RideCompareScreenState();
}

class _RideCompareScreenState extends ConsumerState<RideCompareScreen> {
  CloudRideSummary? _peer;
  List<CloudTrackPoint>? _peerPoints;
  bool _loadingPeerTrack = false;

  @override
  void initState() {
    super.initState();
    _peer = widget.initialPeer;
    if (_peer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPeerTrack());
    }
  }

  Future<void> _selectPeer(CloudRideSummary peer) async {
    setState(() {
      _peer = peer;
      _peerPoints = null;
    });
    await _loadPeerTrack();
  }

  Future<void> _loadPeerTrack() async {
    final peer = _peer;
    if (peer == null) return;
    setState(() => _loadingPeerTrack = true);
    try {
      final points =
          await ref.read(socialRepositoryProvider).trackPoints(peer.id);
      if (!mounted) return;
      setState(() {
        _peerPoints = points;
        _loadingPeerTrack = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPeerTrack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rideAsync = ref.watch(rideProvider(widget.localRideId));
    final pointsAsync = ref.watch(ridePointsProvider(widget.localRideId));
    final peersAsync = ref.watch(overlappingPeersProvider(widget.localRideId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.compareTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: rideAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (ride) {
          if (ride == null) {
            return Center(child: Text(l10n.rideNotFound));
          }
          return pointsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (points) {
              final you = RideAnalytics(ride: ride, points: points);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    l10n.comparePickPeer,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  peersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => Text(
                      l10n.cloudUnavailable,
                      style: const TextStyle(color: AppTheme.steel),
                    ),
                    data: (peers) {
                      if (peers.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            l10n.compareEmpty,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              height: 1.4,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final peer in peers)
                            _PeerPickTile(
                              peer: peer,
                              selected: _peer?.id == peer.id,
                              onTap: () => _selectPeer(peer),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_peer != null) ...[
                    CompareMetricsTable(
                      leftLabel: l10n.compareYou,
                      rightLabel: _peer!.riderLabel,
                      left: CompareRideMetrics.fromAnalytics(you),
                      right: CompareRideMetrics.fromCloud(_peer!),
                    ),
                    const SizedBox(height: 20),
                    if (_loadingPeerTrack)
                      const Center(child: CircularProgressIndicator())
                    else if (_peerPoints != null && points.isNotEmpty) ...[
                      if (_peerPoints!.length < 2)
                        Text(
                          l10n.compareTrackUnavailable,
                          style: GoogleFonts.rajdhani(color: AppTheme.steel),
                        )
                      else
                        DualPolylineMap.fromTrackPoints(
                          left: points,
                          right: trackPointsFromCloud(
                            _peerPoints!,
                            rideId: _peer!.id,
                          ),
                          leftLabel: l10n.compareYou,
                          rightLabel: _peer!.riderLabel,
                          sharedCorridorOnly: true,
                          caption: l10n.compareSharedSectionHelp,
                        ),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PeerPickTile extends StatelessWidget {
  const _PeerPickTile({
    required this.peer,
    required this.selected,
    required this.onTap,
  });

  final CloudRideSummary peer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppTheme.line.withValues(alpha: 0.18)
            : AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppTheme.line : AppTheme.steel,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peer.riderLabel,
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${DateFormat.MMMd().add_jm().format(peer.startedAt.toLocal())} · '
                        '${peer.distanceKm.toStringAsFixed(1)} km · '
                        '${peer.maxSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
                        style: const TextStyle(
                          color: AppTheme.steel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entry that finds peers for [localRideId] (used from Ride Lab).
class ComparePeersEntry extends ConsumerWidget {
  const ComparePeersEntry({super.key, required this.localRideId});

  final String localRideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final peersAsync = ref.watch(overlappingPeersProvider(localRideId));
    final count = peersAsync.maybeWhen(
      data: (p) => p.length,
      orElse: () => null,
    );

    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RideCompareScreen(localRideId: localRideId),
          ),
        );
      },
      icon: const Icon(Icons.compare_arrows),
      label: Text(
        count == null
            ? l10n.compare
            : '${l10n.compare}${count > 0 ? " ($count)" : ""}',
      ),
    );
  }
}
