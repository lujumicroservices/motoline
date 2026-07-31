import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/models/cloud_models.dart';
import '../../core/models/track_point.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';

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
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
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
                    style: GoogleFonts.outfit(
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
                            style: GoogleFonts.outfit(
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
                    _MetricsCompare(
                      youLabel: l10n.compareYou,
                      peerLabel: _peer!.riderLabel,
                      you: _LocalMetrics.fromAnalytics(you),
                      peer: _LocalMetrics.fromCloud(_peer!),
                    ),
                    const SizedBox(height: 20),
                    if (_loadingPeerTrack)
                      const Center(child: CircularProgressIndicator())
                    else if (_peerPoints != null && points.isNotEmpty)
                      _DualLineMap(
                        yours: points,
                        peer: _peerPoints!,
                        youLabel: l10n.compareYou,
                        peerLabel: _peer!.riderLabel,
                      ),
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
                        style: GoogleFonts.spaceGrotesk(
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

class _LocalMetrics {
  const _LocalMetrics({
    required this.distanceKm,
    required this.duration,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.maxLeanLeft,
    required this.maxLeanRight,
    required this.lineScore,
  });

  final double distanceKm;
  final Duration duration;
  final double? maxSpeedKmh;
  final double? avgSpeedKmh;
  final double? maxLeanLeft;
  final double? maxLeanRight;
  final int? lineScore;

  factory _LocalMetrics.fromAnalytics(RideAnalytics a) => _LocalMetrics(
        distanceKm: a.distanceKm,
        duration: a.duration,
        maxSpeedKmh: a.maxSpeedKmh,
        avgSpeedKmh: a.ride.avgSpeedKmh,
        maxLeanLeft: a.maxLeanLeft,
        maxLeanRight: a.maxLeanRight,
        lineScore: a.lineScore,
      );

  factory _LocalMetrics.fromCloud(CloudRideSummary r) => _LocalMetrics(
        distanceKm: r.distanceKm,
        duration: r.duration,
        maxSpeedKmh: r.maxSpeedKmh,
        avgSpeedKmh: r.avgSpeedKmh,
        maxLeanLeft: r.maxLeanLeftDeg,
        maxLeanRight: r.maxLeanRightDeg,
        lineScore: r.lineScore,
      );
}

class _MetricsCompare extends StatelessWidget {
  const _MetricsCompare({
    required this.youLabel,
    required this.peerLabel,
    required this.you,
    required this.peer,
  });

  final String youLabel;
  final String peerLabel;
  final _LocalMetrics you;
  final _LocalMetrics peer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  youLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  peerLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(l10n.distance, _fmtKm(you.distanceKm), _fmtKm(peer.distanceKm)),
          _row(
            l10n.duration,
            formatDuration(you.duration),
            formatDuration(peer.duration),
          ),
          _row(
            l10n.maxSpeed,
            _fmtSpeed(you.maxSpeedKmh, l10n.kmh),
            _fmtSpeed(peer.maxSpeedKmh, l10n.kmh),
          ),
          _row(
            l10n.avgSpeed,
            _fmtSpeed(you.avgSpeedKmh, l10n.kmh),
            _fmtSpeed(peer.avgSpeedKmh, l10n.kmh),
          ),
          _row(
            l10n.maxLR,
            _fmtLean(you.maxLeanLeft, you.maxLeanRight),
            _fmtLean(peer.maxLeanLeft, peer.maxLeanRight),
          ),
          _row(
            l10n.lineScore,
            '${you.lineScore ?? "—"}',
            '${peer.lineScore ?? "—"}',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.steel, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKm(double km) => '${km.toStringAsFixed(2)} km';
  String _fmtSpeed(double? v, String unit) =>
      v == null ? '—' : '${v.toStringAsFixed(0)} $unit';
  String _fmtLean(double? l, double? r) =>
      '${l?.toStringAsFixed(0) ?? "—"}° / ${r?.toStringAsFixed(0) ?? "—"}°';
}

class _DualLineMap extends StatelessWidget {
  const _DualLineMap({
    required this.yours,
    required this.peer,
    required this.youLabel,
    required this.peerLabel,
  });

  final List<TrackPoint> yours;
  final List<CloudTrackPoint> peer;
  final String youLabel;
  final String peerLabel;

  @override
  Widget build(BuildContext context) {
    final youLatLng =
        yours.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final peerLatLng =
        peer.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final all = [...youLatLng, ...peerLatLng];
    if (all.length < 2) {
      return const SizedBox.shrink();
    }
    final bounds = LatLngBounds.fromPoints(all);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(RideVizPalette.leanLeft, youLabel),
            const SizedBox(width: 16),
            _legendDot(RideVizPalette.leanRight, peerLabel),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(36),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.motoline.motoline',
                ),
                PolylineLayer(
                  polylines: [
                    if (youLatLng.length >= 2)
                      Polyline(
                        points: youLatLng,
                        strokeWidth: 4,
                        color: RideVizPalette.leanLeft.withValues(alpha: 0.9),
                      ),
                    if (peerLatLng.length >= 2)
                      Polyline(
                        points: peerLatLng,
                        strokeWidth: 4,
                        color: RideVizPalette.leanRight.withValues(alpha: 0.9),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.steel, fontSize: 12)),
      ],
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
