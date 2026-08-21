import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/ride.dart';
import '../../core/models/route_circuit.dart';
import '../../core/models/route_loop.dart';
import '../../core/services/ride_recorder.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../compare/route_compare_screen.dart';
import '../ride_active/active_ride_screen.dart';
import '../ride_active/armed_session_flow.dart';
import '../ride_active/armed_session_nav.dart';
import '../ride_active/widgets/upright_freeze_sheet.dart';
import '../ride_active/loop_mark_map_screen.dart';
import '../ride_detail/ride_detail_screen.dart';

/// Detail for one route: tagged laps + Loop module (detect / define / ride).
class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key, required this.route});

  final RouteCircuit route;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<DetectedLoopCandidate>? _detected;
  bool _detecting = false;

  RouteCircuit get route => widget.route;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _runDetection() async {
    setState(() {
      _detecting = true;
      _detected = null;
    });
    try {
      final found =
          await ref.read(routeLoopServiceProvider).detectForRoute(route.id);
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

  Future<void> _defineManual() async {
    final l10n = context.l10n;
    final preview =
        await ref.read(routeLoopServiceProvider).trackPreviewForRoute(route.id);
    if (!mounted) return;

    final loops = ref.read(routeLoopsProvider(route.id)).valueOrNull ?? [];
    RouteLoop? primary;
    for (final l in loops) {
      if (l.isPrimary) {
        primary = l;
        break;
      }
    }
    primary ??= loops.isEmpty ? null : loops.first;

    final result = await Navigator.of(context).push<LoopMarkResult>(
      MaterialPageRoute(
        builder: (_) => LoopMarkMapScreen(
          points: preview,
          initialInit: primary == null
              ? null
              : LatLng(primary.initLat, primary.initLng),
          initialEnd: primary == null
              ? null
              : LatLng(primary.endLat, primary.endLng),
        ),
      ),
    );
    if (result == null || !mounted) return;

    await ref.read(routeLoopServiceProvider).saveManual(
          routeId: route.id,
          name: l10n.routeLoopManualName,
          initLat: result.init.latitude,
          initLng: result.init.longitude,
          endLat: result.end.latitude,
          endLng: result.end.longitude,
        );
    ref.invalidate(routeLoopsProvider(route.id));
    ref.invalidate(routesListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.routeLoopSaved)),
    );
  }

  Future<void> _saveDetected(DetectedLoopCandidate c) async {
    final l10n = context.l10n;
    await ref.read(routeLoopServiceProvider).saveDetected(
          routeId: route.id,
          candidate: c,
        );
    ref.invalidate(routeLoopsProvider(route.id));
    ref.invalidate(routesListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.routeLoopSaved)),
    );
  }

  Future<void> _startLoopRide(RouteLoop loop) async {
    final fresh = await ref.read(routeServiceProvider).listLocal();
    RouteCircuit current = route;
    for (final r in fresh) {
      if (r.id == route.id) {
        current = r;
        break;
      }
    }
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RideRecorder.preferredArmRoutePrefKey, route.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveRideScreen(
          autoStart: false,
          mode: ActiveRideMode.loop,
          route: current,
          loop: loop,
        ),
      ),
    );
    ref.invalidate(ridesListProvider);
    ref.invalidate(ridesForRouteProvider(route.id));
  }

  Future<void> _armAutoForRoute() async {
    final l10n = context.l10n;
    try {
      final ok = await freezeThenArm(context, ref, routeId: route.id);
      if (!ok || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.armAutoRouteArmedNamed(route.name))),
      );
      Navigator.of(context).popUntil((r) => r.isFirst);
      if (!mounted) return;
      ref.read(armedSessionNavProvider.notifier).reset();
      ensureArmedSessionHub(context, ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loopsAsync = ref.watch(routeLoopsProvider(route.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          route.name,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear_loops') await _confirmClearLoops();
              if (v == 'delete_route') await _confirmDeleteRoute();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'clear_loops',
                child: Text(l10n.deleteAllLoops),
              ),
              PopupMenuItem(
                value: 'delete_route',
                child: Text(
                  l10n.deleteRoute,
                  style: const TextStyle(color: AppTheme.signal),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.routeTabLaps),
            Tab(text: l10n.routeTabLoop),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LapsTab(route: route),
          _LoopModuleTab(
            route: route,
            loopsAsync: loopsAsync,
            detected: _detected,
            detecting: _detecting,
            onDetect: _runDetection,
            onDefineManual: _defineManual,
            onSaveDetected: _saveDetected,
            onStart: _startLoopRide,
            onArm: _armAutoForRoute,
            onSetPrimary: (id) async {
              await ref
                  .read(routeLoopServiceProvider)
                  .setPrimary(route.id, id);
              ref.invalidate(routeLoopsProvider(route.id));
              ref.invalidate(routesListProvider);
            },
            onDelete: (id) async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await _confirm(
                title: l10n.deleteLoop,
                body: l10n.deleteLoopBody,
              );
              if (ok != true || !mounted) return;
              await ref.read(routeLoopServiceProvider).deleteLoop(id);
              ref.invalidate(routeLoopsProvider(route.id));
              ref.invalidate(routesListProvider);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.loopDeleted)),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm({required String title, required String body}) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(
          title,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        content: Text(
          body,
          style: GoogleFonts.rajdhani(color: AppTheme.steel, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.close),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.signal),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearLoops() async {
    final l10n = context.l10n;
    final ok = await _confirm(
      title: l10n.deleteAllLoops,
      body: l10n.deleteAllLoopsBody,
    );
    if (ok != true || !mounted) return;
    await ref.read(routeLoopServiceProvider).deleteAllLoops(route.id);
    ref.invalidate(routeLoopsProvider(route.id));
    ref.invalidate(routesListProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.loopsCleared)),
    );
  }

  Future<void> _confirmDeleteRoute() async {
    final l10n = context.l10n;
    final ok = await _confirm(
      title: l10n.deleteRoute,
      body: l10n.deleteRouteBody,
    );
    if (ok != true || !mounted) return;
    await ref.read(routeServiceProvider).deleteRoute(route.id);
    ref.invalidate(routesListProvider);
    ref.invalidate(sharedPeerRoutesProvider);
    ref.invalidate(ridesListProvider);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.routeDeleted)),
    );
  }
}

class _LapsTab extends ConsumerWidget {
  const _LapsTab({required this.route});

  final RouteCircuit route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(ridesForRouteProvider(route.id));

    return ridesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (rides) {
        final completed =
            rides.where((r) => r.status == RideStatus.completed).toList();
        if (completed.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.routesEmpty,
              style: const TextStyle(color: AppTheme.steel),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            if (completed.length >= 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RouteCompareScreen(
                          routeId: route.id,
                          routeName: route.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.timeline),
                  label: Text(l10n.compareLaps),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.compareNeedTwoLaps,
                  style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                ),
              ),
            for (final ride in completed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  DateFormat.MMMd().add_jm().format(ride.startedAt),
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${ride.distanceKm.toStringAsFixed(2)} km'
                  '${ride.maxSpeedKmh == null ? '' : ' · max ${ride.maxSpeedKmh!.toStringAsFixed(0)} km/h'}',
                  style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.deleteRide,
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.deleteRide),
                            content: Text(l10n.deleteRideBody),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.notNow),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.signal,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(l10n.deleteConfirm),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        await ref
                            .read(rideSyncServiceProvider)
                            .deleteRideEverywhere(ride.id);
                        ref.invalidate(ridesForRouteProvider(route.id));
                        ref.invalidate(ridesListProvider);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.rideDeleted)),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      color: AppTheme.signal,
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.steel),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RideDetailScreen(rideId: ride.id),
                    ),
                  ).then((_) {
                    ref.invalidate(ridesForRouteProvider(route.id));
                  });
                },
              ),
          ],
        );
      },
    );
  }
}

class _LoopModuleTab extends StatelessWidget {
  const _LoopModuleTab({
    required this.route,
    required this.loopsAsync,
    required this.detected,
    required this.detecting,
    required this.onDetect,
    required this.onDefineManual,
    required this.onSaveDetected,
    required this.onStart,
    required this.onArm,
    required this.onSetPrimary,
    required this.onDelete,
  });

  final RouteCircuit route;
  final AsyncValue<List<RouteLoop>> loopsAsync;
  final List<DetectedLoopCandidate>? detected;
  final bool detecting;
  final VoidCallback onDetect;
  final VoidCallback onDefineManual;
  final ValueChanged<DetectedLoopCandidate> onSaveDetected;
  final ValueChanged<RouteLoop> onStart;
  final VoidCallback onArm;
  final ValueChanged<String> onSetPrimary;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          l10n.routeLoopModuleHelp,
          style: GoogleFonts.rajdhani(
            color: AppTheme.steel,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onDefineManual,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(l10n.routeLoopDefine),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: detecting ? null : onDetect,
                icon: detecting
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
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onArm,
          icon: const Icon(Icons.sensors),
          label: Text(l10n.armAutoRide),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.routeLoopSavedTitle,
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        loopsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('$e'),
          data: (loops) {
            if (loops.isEmpty) {
              return Text(
                l10n.routeLoopEmpty,
                style: const TextStyle(color: AppTheme.steel, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (final loop in loops)
                  _SavedLoopTile(
                    loop: loop,
                    onStart: () => onStart(loop),
                    onPrimary: () => onSetPrimary(loop.id),
                    onDelete: () => onDelete(loop.id),
                  ),
              ],
            );
          },
        ),
        if (detected != null) ...[
          const SizedBox(height: 28),
          Text(
            l10n.routeLoopDetectedTitle,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (detected!.isEmpty)
            Text(
              l10n.routeLoopDetectedEmpty,
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            )
          else
            for (final c in detected!)
              _DetectedTile(
                candidate: c,
                onSave: () => onSaveDetected(c),
              ),
        ],
      ],
    );
  }
}

class _SavedLoopTile extends StatelessWidget {
  const _SavedLoopTile({
    required this.loop,
    required this.onStart,
    required this.onPrimary,
    required this.onDelete,
  });

  final RouteLoop loop;
  final VoidCallback onStart;
  final VoidCallback onPrimary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: AppTheme.asphaltElevated,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.all_inclusive,
                  size: 18,
                  color: loop.isPrimary
                      ? RideVizPalette.leanLeft
                      : AppTheme.steel,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loop.name,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (loop.isPrimary)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      l10n.routeLoopPrimary,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: RideVizPalette.leanLeft,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'primary') onPrimary();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    if (!loop.isPrimary)
                      PopupMenuItem(
                        value: 'primary',
                        child: Text(l10n.routeLoopSetPrimary),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.deleteLoop,
                        style: const TextStyle(color: AppTheme.signal),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${loop.source == 'detected' ? l10n.routeLoopSourceDetected : l10n.routeLoopSourceManual}'
              ' · ±${loop.geofenceRadiusM.toStringAsFixed(0)} m',
              style: const TextStyle(color: AppTheme.steel, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.routeLoopStartRide),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedTile extends StatelessWidget {
  const _DetectedTile({
    required this.candidate,
    required this.onSave,
  });

  final DetectedLoopCandidate candidate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      color: AppTheme.asphaltElevated,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          '${(candidate.pathMeters / 1000).toStringAsFixed(2)} km · '
          '${formatDuration(candidate.duration)}',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          l10n.routeLoopDetectedHint,
          style: const TextStyle(color: AppTheme.steel, fontSize: 12),
        ),
        trailing: TextButton(
          onPressed: onSave,
          child: Text(l10n.routeLoopSave),
        ),
      ),
    );
  }
}
