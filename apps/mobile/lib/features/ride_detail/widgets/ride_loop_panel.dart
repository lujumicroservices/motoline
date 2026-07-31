import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/ride.dart';
import '../../../core/models/route_loop.dart';
import '../../../core/models/track_point.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ride_viz_palette.dart';
import '../../ride_active/loop_mark_map_screen.dart';
import '../../routes/route_detail_screen.dart';

/// Loop discover / define module inside Ride Lab for one ride.
class RideLoopPanel extends ConsumerStatefulWidget {
  const RideLoopPanel({
    super.key,
    required this.ride,
    required this.points,
  });

  final Ride ride;
  final List<TrackPoint> points;

  @override
  ConsumerState<RideLoopPanel> createState() => _RideLoopPanelState();
}

class _RideLoopPanelState extends ConsumerState<RideLoopPanel> {
  List<DetectedLoopCandidate>? _detected;
  bool _detecting = false;
  bool _busy = false;

  Future<String> _ensureRouteId() async {
    final existingId = widget.ride.routeId;
    if (existingId != null) {
      final route = await ref.read(rideDatabaseProvider).getRoute(existingId);
      if (route != null) return route.id;
    }

    final when = DateFormat('yyyy-MM-dd HH:mm').format(widget.ride.startedAt);
    final route = await ref.read(routeServiceProvider).createRoute(
          name: 'Loop $when',
          isShared: true,
        );
    final updated = widget.ride.copyWith(routeId: route.id);
    await ref.read(rideDatabaseProvider).upsertRide(updated);
    // Best-effort cloud retag.
    try {
      await ref.read(rideSyncServiceProvider).syncRide(updated.id);
    } catch (_) {}
    ref.invalidate(rideProvider(widget.ride.id));
    ref.invalidate(routesListProvider);
    return route.id;
  }

  Future<void> _detect() async {
    setState(() {
      _detecting = true;
      _detected = null;
    });
    try {
      final found = await ref
          .read(routeLoopServiceProvider)
          .detectForRide(widget.ride.id);
      if (!mounted) return;
      setState(() {
        _detected = found;
        _detecting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _detecting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _markManual() async {
    final l10n = context.l10n;
    if (widget.points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rideLoopNeedPoints)),
      );
      return;
    }

    final result = await Navigator.of(context).push<LoopMarkResult>(
      MaterialPageRoute(
        builder: (_) => LoopMarkMapScreen(points: widget.points),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final routeId = await _ensureRouteId();
      await ref.read(routeLoopServiceProvider).saveManual(
            routeId: routeId,
            name: l10n.routeLoopManualName,
            initLat: result.init.latitude,
            initLng: result.init.longitude,
            endLat: result.end.latitude,
            endLng: result.end.longitude,
          );
      ref.invalidate(routeLoopsProvider(routeId));
      ref.invalidate(routesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.routeLoopSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDetected(DetectedLoopCandidate c) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final routeId = await _ensureRouteId();
      await ref.read(routeLoopServiceProvider).saveDetected(
            routeId: routeId,
            candidate: c,
          );
      ref.invalidate(routeLoopsProvider(routeId));
      ref.invalidate(routesListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.routeLoopSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRoute() async {
    final id = widget.ride.routeId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.rideLoopSaveFirst)),
      );
      return;
    }
    final route = await ref.read(rideDatabaseProvider).getRoute(id);
    if (route == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RouteDetailScreen(route: route),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final routeId = widget.ride.routeId;
    final loopsAsync = routeId == null
        ? const AsyncValue<List<RouteLoop>>.data([])
        : ref.watch(routeLoopsProvider(routeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.rideLoopHelp,
          style: GoogleFonts.outfit(
            color: AppTheme.steel,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy ? null : _markManual,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(l10n.routeLoopDefine),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_busy || _detecting) ? null : _detect,
                icon: _detecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(l10n.routeLoopDetect),
              ),
            ),
          ],
        ),
        if (routeId != null) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _openRoute,
            icon: const Icon(Icons.route_outlined, size: 18),
            label: Text(l10n.rideLoopOpenRoute),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.routeLoopSavedTitle,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        loopsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (loops) {
            if (loops.isEmpty) {
              return Text(
                l10n.rideLoopEmpty,
                style: const TextStyle(color: AppTheme.steel, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final loop in loops)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.all_inclusive,
                          size: 16,
                          color: loop.isPrimary
                              ? RideVizPalette.leanLeft
                              : AppTheme.steel,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loop.name,
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (loop.isPrimary)
                          Text(
                            l10n.routeLoopPrimary,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: RideVizPalette.leanLeft,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (_detected != null) ...[
          const SizedBox(height: 16),
          Text(
            l10n.routeLoopDetectedTitle,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (_detected!.isEmpty)
            Text(
              l10n.rideLoopDetectedEmpty,
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            )
          else
            for (final c in _detected!)
              Card(
                color: AppTheme.asphaltElevated,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${(c.pathMeters / 1000).toStringAsFixed(2)} km · '
                    '${formatDuration(c.duration)}',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.routeLoopDetectedHint,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _saveDetected(c),
                    child: Text(l10n.routeLoopSave),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
