import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/models/ride.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import 'compare_widgets.dart';

/// Local compare: pick two completed rides that share a [routeId].
class RouteCompareScreen extends ConsumerStatefulWidget {
  const RouteCompareScreen({
    super.key,
    required this.routeId,
    this.routeName,
    this.baselineRideId,
  });

  final String routeId;
  final String? routeName;
  final String? baselineRideId;

  @override
  ConsumerState<RouteCompareScreen> createState() => _RouteCompareScreenState();
}

class _RouteCompareScreenState extends ConsumerState<RouteCompareScreen> {
  String? _baselineId;
  String? _challengerId;

  List<Ride> _completed(List<Ride> rides) => rides
      .where((r) => r.status == RideStatus.completed)
      .toList(growable: false);

  (String baseline, String challenger) _resolvePair(List<Ride> rides) {
    var baseline = _baselineId;
    if (baseline == null || !rides.any((r) => r.id == baseline)) {
      baseline = widget.baselineRideId;
      if (baseline == null || !rides.any((r) => r.id == baseline)) {
        baseline = rides.first.id;
      }
    }
    var challenger = _challengerId;
    if (challenger == null ||
        challenger == baseline ||
        !rides.any((r) => r.id == challenger)) {
      challenger = rides.firstWhere((r) => r.id != baseline).id;
    }
    return (baseline, challenger);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(ridesForRouteProvider(widget.routeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routeName?.isNotEmpty == true
              ? l10n.compareRouteTitle(widget.routeName!)
              : l10n.compareLocalTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final rides = _completed(all);
          if (rides.length < 2) {
            return Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(
                  l10n.compareLocalEmpty,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }

          final pair = _resolvePair(rides);
          final baselineId = pair.$1;
          final challengerId = pair.$2;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                l10n.compareLocalHelp,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.compareBaseline,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: RideVizPalette.leanLeft,
                ),
              ),
              const SizedBox(height: 8),
              for (final ride in rides)
                _LocalPickTile(
                  ride: ride,
                  selected: ride.id == baselineId,
                  accent: RideVizPalette.leanLeft,
                  onTap: () {
                    setState(() {
                      _baselineId = ride.id;
                      if (_challengerId == ride.id) {
                        _challengerId =
                            rides.firstWhere((r) => r.id != ride.id).id;
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
              Text(
                l10n.compareChallenger,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: RideVizPalette.leanRight,
                ),
              ),
              const SizedBox(height: 8),
              for (final ride in rides.where((r) => r.id != baselineId))
                _LocalPickTile(
                  ride: ride,
                  selected: ride.id == challengerId,
                  accent: RideVizPalette.leanRight,
                  onTap: () => setState(() => _challengerId = ride.id),
                ),
              const SizedBox(height: 20),
              _LocalPairCompare(
                baselineId: baselineId,
                challengerId: challengerId,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocalPickTile extends StatelessWidget {
  const _LocalPickTile({
    required this.ride,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final Ride ride;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.18)
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
                  color: selected ? accent : AppTheme.steel,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.MMMd().add_jm().format(ride.startedAt),
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${ride.distanceKm.toStringAsFixed(2)} km · '
                        '${formatDuration(ride.duration)}'
                        '${ride.maxSpeedKmh == null ? '' : ' · ${ride.maxSpeedKmh!.toStringAsFixed(0)} ${l10n.kmh}'}',
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

class _LocalPairCompare extends ConsumerWidget {
  const _LocalPairCompare({
    required this.baselineId,
    required this.challengerId,
  });

  final String baselineId;
  final String challengerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final baseRide = ref.watch(rideProvider(baselineId));
    final chalRide = ref.watch(rideProvider(challengerId));
    final basePts = ref.watch(ridePointsProvider(baselineId));
    final chalPts = ref.watch(ridePointsProvider(challengerId));

    if (baseRide.isLoading ||
        chalRide.isLoading ||
        basePts.isLoading ||
        chalPts.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final br = baseRide.valueOrNull;
    final cr = chalRide.valueOrNull;
    final bp = basePts.valueOrNull;
    final cp = chalPts.valueOrNull;
    if (br == null || cr == null || bp == null || cp == null) {
      return Text(l10n.rideNotFound);
    }

    final left = RideAnalytics(ride: br, points: bp);
    final right = RideAnalytics(ride: cr, points: cp);
    final delta = cr.duration - br.duration;
    final deltaLabel = delta.isNegative
        ? l10n.compareDeltaFaster(formatDuration(delta.abs()))
        : (delta.inSeconds == 0
            ? l10n.compareDeltaTie
            : l10n.compareDeltaSlower(formatDuration(delta)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.asphaltElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (delta.isNegative
                      ? RideVizPalette.leanLeft
                      : AppTheme.steel)
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            deltaLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 16),
        CompareMetricsTable(
          leftLabel: l10n.compareBaseline,
          rightLabel: l10n.compareChallenger,
          left: CompareRideMetrics.fromAnalytics(left),
          right: CompareRideMetrics.fromAnalytics(right),
        ),
        const SizedBox(height: 20),
        DualPolylineMap.fromTrackPoints(
          left: left.samples,
          right: right.samples,
          leftLabel: l10n.compareBaseline,
          rightLabel: l10n.compareChallenger,
          sharedCorridorOnly: true,
          caption: l10n.compareSharedSectionHelp,
        ),
      ],
    );
  }
}

/// Opens local route compare when this ride has a tagged route with ≥2 laps.
class CompareLocalRouteEntry extends ConsumerWidget {
  const CompareLocalRouteEntry({
    super.key,
    required this.ride,
  });

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeId = ride.routeId;
    if (routeId == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final siblings = ref.watch(ridesForRouteProvider(routeId));
    final count = siblings.maybeWhen(
      data: (rides) =>
          rides.where((r) => r.status == RideStatus.completed).length,
      orElse: () => 0,
    );
    if (count < 2) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RouteCompareScreen(
              routeId: routeId,
              baselineRideId: ride.id,
            ),
          ),
        );
      },
      icon: const Icon(Icons.timeline),
      label: Text(l10n.compareLocal(count)),
    );
  }
}
