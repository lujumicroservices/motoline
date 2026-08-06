import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/models/route_circuit.dart';
import '../../core/models/route_loop.dart';
import '../../core/models/track_point.dart';
import '../../core/services/location_service.dart';
import '../../core/services/loop_session_controller.dart';
import '../../core/services/rider_telemetry_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../l10n/gps_warmup_l10n.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../adventure_camera/widgets/adventure_camera_ride_controls.dart';
import '../adventure_camera/widgets/adventure_camera_status_chip.dart';
import '../lean_lab/lean_lab_bootstrap.dart';
import '../lean_lab/lean_lab_review_screen.dart';
import '../ride_detail/pilot_line_map.dart';
import '../telemetry/ride_engine_label_screen.dart';
import 'loop_mark_map_screen.dart';
import 'widgets/gps_status_widgets.dart';

/// Normal = single ride. Loop = auto-lap session bound to a route loop.
enum ActiveRideMode { normal, loop }

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({
    super.key,
    this.autoStart = true,
    this.mode = ActiveRideMode.normal,
    this.route,
    this.loop,
    this.leanLabBootstrap,
  });

  /// When true, starts the recorder (with GPS warm-up UI) on open.
  final bool autoStart;

  final ActiveRideMode mode;

  /// When set with [mode] = loop, tags laps to this route.
  final RouteCircuit? route;

  /// Optional saved loop — arms auto-lap as soon as recording starts.
  final RouteLoop? loop;

  /// When set, attaches a Lean Lab session after recording starts.
  final LeanLabRideBootstrap? leanLabBootstrap;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Timer? _tick;
  bool _starting = false;
  GnssWarmupStatus? _warmup;
  Object? _startError;
  bool _keepRidingDismissed = false;

  bool get _isLoop => widget.mode == ActiveRideMode.loop;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoStart) {
        unawaited(_bootstrap());
      } else {
        unawaited(_attachIfAlreadyRecording());
      }
    });
  }

  /// Arm-auto already started the recorder; still bind route/loop so laps
  /// count under the ruta and auto-lap works.
  Future<void> _attachIfAlreadyRecording() async {
    final recorder = ref.read(rideRecorderProvider);
    if (!recorder.isRecording) return;

    final route = widget.route;
    if (route != null) {
      final active = recorder.activeRide;
      if (active?.routeId != route.id) {
        await recorder.setActiveRideRouteId(route.id);
      }
      if (_isLoop) {
        final loopCtrl = ref.read(loopSessionControllerProvider);
        await loopCtrl.bindRoute(route, loop: widget.loop);
      }
    }
    if (mounted) ref.invalidate(activeRideProvider);
  }

  Future<void> _bootstrap() async {
    final recorder = ref.read(rideRecorderProvider);
    if (recorder.isRecording) {
      await _attachIfAlreadyRecording();
      return;
    }

    setState(() {
      _starting = true;
      _startError = null;
      _warmup = const GnssWarmupStatus(
        phase: GpsWarmupPhase.permissions,
      );
    });

    try {
      await recorder.start(
        onWarmup: (status) {
          if (!mounted) return;
          setState(() => _warmup = status);
        },
        routeId: widget.route?.id,
      );
      if (!mounted) return;

      final leanLab = widget.leanLabBootstrap;
      final started = recorder.activeRide;
      if (leanLab != null && started != null) {
        recorder.lockLeanNeutral(leanLab.frozenNeutralDeg);
        await LeanLabService.instance.beginSession(
          rideId: started.id,
          sessionType: leanLab.sessionType,
          direction: leanLab.direction,
          phoneMount: leanLab.phoneMount,
          phonePose: leanLab.phonePose,
          frozenNeutralDeg: leanLab.frozenNeutralDeg,
          calibAt: leanLab.calibAt,
        );
      }

      if (_isLoop && widget.route != null) {
        final loopCtrl = ref.read(loopSessionControllerProvider);
        await loopCtrl.bindRoute(widget.route!, loop: widget.loop);
      }

      if (!mounted) return;
      setState(() {
        _starting = false;
        _warmup = null;
      });
      ref.invalidate(activeRideProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _startError = e;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshotAsync = ref.watch(activeRideProvider);
    final recorder = ref.watch(rideRecorderProvider);
    final ride = recorder.activeRide;
    final snap = snapshotAsync.valueOrNull;
    final isPaused = snap?.isPaused ?? false;
    final rawSuggestEnd = snap?.suggestEnd ?? false;
    if (!rawSuggestEnd && _keepRidingDismissed) {
      // Motion resumed — rearm the banner for a future stationary spell.
      _keepRidingDismissed = false;
    }
    final suggestEnd = rawSuggestEnd && !_keepRidingDismissed;

    final loopStateAsync = _isLoop ? ref.watch(loopSessionStateProvider) : null;
    final loopState = loopStateAsync?.valueOrNull;

    final isRecording = recorder.isRecording;
    final staging = !widget.autoStart &&
        !isRecording &&
        !_starting &&
        _startError == null;

    return PopScope(
      canPop: !_starting && !isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_starting) return;
        // Recording: use End ride / End session.
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _starting
                ? l10n.starting
                : staging
                    ? l10n.rideDeckTitle
                    : _isLoop
                        ? l10n.loopMode
                        : l10n.recording,
          ),
          automaticallyImplyLeading: false,
          leading: (_starting || isRecording)
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          actions: [
            if (!_starting && (isRecording || staging)) ...[
              const AdventureCameraStatusChip(),
              if (isRecording)
                if (isPaused)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatusChip(
                      label: l10n.pausedLabel,
                      color: AppTheme.lineHot,
                      icon: Icons.pause_circle_outline,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _StatusChip(
                      label: l10n.live,
                      color: AppTheme.signal,
                      icon: null,
                      dotted: true,
                    ),
                  ),
            ],
          ],
        ),
        body: _starting
            ? GpsWarmupPanel(
                status: _warmup ??
                    const GnssWarmupStatus(
                      phase: GpsWarmupPhase.searching,
                    ),
              )
            : _startError != null
                ? _StartErrorBody(
                    error: context.l10n.userFacingError(_startError!),
                    onRetry: _bootstrap,
                    onBack: () => Navigator.of(context).pop(),
                  )
                : staging
                    ? _RideDeckBody(onStartRide: _bootstrap)
                    : Column(
                    children: [
                      if (suggestEnd)
                        _SuggestEndBanner(
                          onKeepRiding: () =>
                              setState(() => _keepRidingDismissed = true),
                          onEnd: () => _isLoop
                              ? _endLoopSession(context)
                              : _stop(context),
                        ),
                      Expanded(
                        child: snapshotAsync.when(
                          loading: () => _body(
                            context,
                            distanceKm: ride?.distanceKm ?? 0,
                            duration: ride?.duration ?? Duration.zero,
                            points: const <TrackPoint>[],
                            pointCount: ride?.pointCount ?? 0,
                            speedKmh: null,
                            leanDegrees: null,
                            maxLeanLeft: 0,
                            maxLeanRight: 0,
                            leanCalibrated: false,
                            accuracyMeters: null,
                            loopState: loopState,
                          ),
                          error: (e, _) => Center(child: Text('$e')),
                          data: (snap) {
                            final r = snap?.ride ?? ride;
                            return _body(
                              context,
                              distanceKm: r?.distanceKm ?? 0,
                              duration: r?.duration ?? Duration.zero,
                              points: snap?.points ?? const <TrackPoint>[],
                              pointCount: r?.pointCount ?? 0,
                              speedKmh: snap?.lastPoint?.speedKmh,
                              leanDegrees: snap?.relativeLeanDegrees,
                              maxLeanLeft: snap?.maxLeanLeftDegrees ?? 0,
                              maxLeanRight: snap?.maxLeanRightDegrees ?? 0,
                              leanCalibrated: snap?.leanCalibrated ?? false,
                              accuracyMeters: snap?.lastPoint?.accuracyMeters,
                              loopState: loopState,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _body(
    BuildContext context, {
    required double distanceKm,
    required Duration duration,
    required List<TrackPoint> points,
    required int pointCount,
    required double? speedKmh,
    required double? leanDegrees,
    required double maxLeanLeft,
    required double maxLeanRight,
    required bool leanCalibrated,
    required double? accuracyMeters,
    required LoopSessionState? loopState,
  }) {
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Row(
            children: [
              GpsLockBadge(accuracyMeters: accuracyMeters),
              const Spacer(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(
            l10n.activeMountHelp,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.distance,
                  value: distanceKm.toStringAsFixed(2),
                  unit: 'km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: l10n.time,
                  value: formatDuration(duration),
                  unit: '',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.speed,
                  value: speedKmh == null
                      ? '--'
                      : speedKmh.toStringAsFixed(0),
                  unit: l10n.kmh,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: leanCalibrated ? l10n.bikeLean : l10n.calibrating,
                  value: leanDegrees == null
                      ? '--'
                      : leanDegrees.abs().toStringAsFixed(0),
                  unit: leanDegrees == null
                      ? '°'
                      : (leanDegrees.abs() < 2
                          ? '°'
                          : (leanDegrees >= 0
                              ? '° ${l10n.rightShort}'
                              : '° ${l10n.leftShort}')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: l10n.points,
                  value: '$pointCount',
                  unit: '',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: l10n.maxLR,
                  value:
                      '${maxLeanLeft.toStringAsFixed(0)}/${maxLeanRight.toStringAsFixed(0)}',
                  unit: '°',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Stack(
              children: [
                Positioned.fill(
                  child: PilotLineMap(
                    points: points,
                    interactive: true,
                    showStartEnd: !_isLoop,
                  ),
                ),
                if (_isLoop)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        tooltip: l10n.loopOpenMarkMap,
                        onPressed: () => _openLoopMarkMap(points, loopState),
                        icon: const Icon(Icons.fullscreen),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_isLoop) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: _AutoPauseToggleRow(
              enabled: ref.watch(rideRecorderProvider).autoPauseEnabled,
              isPaused: ref.watch(activeRideProvider).valueOrNull?.isPaused ??
                  false,
              onChanged: (value) async {
                await ref.read(rideRecorderProvider).setAutoPauseEnabled(value);
                if (context.mounted) setState(() {});
              },
            ),
          ),
          _LoopHud(
            loopState: loopState,
            points: points,
            onOpenMarkMap: () => _openLoopMarkMap(points, loopState),
            onEndSession: () => _endLoopSession(context),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              children: [
                _AutoPauseToggleRow(
                  enabled: ref.watch(rideRecorderProvider).autoPauseEnabled,
                  isPaused: ref.watch(activeRideProvider).valueOrNull?.isPaused ??
                      false,
                  onChanged: (value) async {
                    await ref
                        .read(rideRecorderProvider)
                        .setAutoPauseEnabled(value);
                    if (context.mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.signal,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _stop(context),
                  child: Text(l10n.endRide),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openLoopMarkMap(
    List<TrackPoint> points,
    LoopSessionState? loopState,
  ) async {
    final route = loopState?.route;
    final result = await Navigator.of(context).push<LoopMarkResult>(
      MaterialPageRoute(
        builder: (_) => LoopMarkMapScreen(
          points: points,
          initialInit: route?.hasLoopInit == true
              ? LatLng(route!.initLat!, route.initLng!)
              : null,
          initialEnd: route?.hasLoopEnd == true
              ? LatLng(route!.endLat!, route.endLng!)
              : null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    try {
      final loop = ref.read(loopSessionControllerProvider);
      await loop.markInit(lat: result.init.latitude, lng: result.init.longitude);
      await loop.markEnd(lat: result.end.latitude, lng: result.end.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _stop(BuildContext context) async {
    final recorder = ref.read(rideRecorderProvider);
    try {
      final ride = await recorder.stop();
      // Closed beta: share with friends (soft-fail offline).
      unawaited(ref.read(rideSyncServiceProvider).syncRide(ride.id));
      final points =
          await ref.read(rideDatabaseProvider).getPoints(ride.id);
      await LeanLabService.instance.finalizeTrackStats(
        rideId: ride.id,
        samples: points,
      );
      if (!context.mounted) return;
      final leanSession =
          await LeanLabService.instance.getSession(ride.id);
      if (!context.mounted) return;
      if (leanSession != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LeanLabReviewScreen(rideId: ride.id),
          ),
        );
        return;
      }
      // Beta: collect mount/lean/brake labels before Ride Lab.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RideEngineLabelScreen(rideId: ride.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _endLoopSession(BuildContext context) async {
    final loopController = ref.read(loopSessionControllerProvider);
    try {
      await loopController.endSession();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _RideDeckBody extends StatefulWidget {
  const _RideDeckBody({required this.onStartRide});

  final Future<void> Function() onStartRide;

  @override
  State<_RideDeckBody> createState() => _RideDeckBodyState();
}

class _RideDeckBodyState extends State<_RideDeckBody> {
  @override
  void initState() {
    super.initState();
    unawaited(
      RiderTelemetryService.instance.log(
        category: TelemetryCategory.app,
        eventType: 'ride_deck_open',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.rideDeckHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            const AdventureCameraRideControls(),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.mist,
                foregroundColor: AppTheme.asphalt,
                minimumSize: const Size.fromHeight(72),
                textStyle: GoogleFonts.exo2(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              onPressed: () {
                unawaited(
                  RiderTelemetryService.instance.log(
                    category: TelemetryCategory.app,
                    eventType: 'ride_deck_start_tapped',
                  ),
                );
                widget.onStartRide();
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 36),
              label: Text(l10n.startRideNow),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
    this.dotted = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dotted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotted)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.exo2(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoPauseToggleRow extends StatelessWidget {
  const _AutoPauseToggleRow({
    required this.enabled,
    required this.isPaused,
    required this.onChanged,
  });

  final bool enabled;
  final bool isPaused;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(
              enabled
                  ? (isPaused
                      ? Icons.pause_circle_filled
                      : Icons.pause_circle_outline)
                  : Icons.play_circle_outline,
              size: 20,
              color: enabled ? AppTheme.lineHot : AppTheme.steel,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.autoPauseToggle,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    l10n.autoPauseToggleHint,
                    style: const TextStyle(
                      color: AppTheme.steel,
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppTheme.lineHot,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestEndBanner extends StatelessWidget {
  const _SuggestEndBanner({required this.onKeepRiding, required this.onEnd});

  final VoidCallback onKeepRiding;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineHot.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.lineHot, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.suggestEndTitle,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.suggestEndBody,
            style: const TextStyle(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onKeepRiding,
                  child: Text(l10n.keepRiding),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.signal),
                  onPressed: onEnd,
                  child: Text(l10n.endRide),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopHud extends StatelessWidget {
  const _LoopHud({
    required this.loopState,
    required this.points,
    required this.onOpenMarkMap,
    required this.onEndSession,
  });

  final LoopSessionState? loopState;
  final List<TrackPoint> points;
  final VoidCallback onOpenMarkMap;
  final VoidCallback onEndSession;

  static Future<void> _runLoopAction(
    BuildContext context,
    Future<void> action,
  ) async {
    try {
      await action;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = loopState;
    final hasInit = state?.hasInit ?? false;
    final hasEnd = state?.hasEnd ?? false;
    final lapCount = state?.lapCount ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasEnd) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.line.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.loopArmed,
                    style: GoogleFonts.exo2(
                      color: AppTheme.line,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.lapCountLabel(lapCount),
                    style: GoogleFonts.exo2(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: points.isEmpty ? null : onOpenMarkMap,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(l10n.loopOpenMarkMap),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: points.isEmpty ? null : onOpenMarkMap,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: RideVizPalette.leanLeft,
                foregroundColor: AppTheme.asphalt,
              ),
              icon: const Icon(Icons.map_outlined),
              label: Text(
                l10n.loopOpenMarkMap,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.loopMarkMapHint,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 12,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                return OutlinedButton.icon(
                  onPressed: hasInit
                      ? null
                      : () => _runLoopAction(
                          context,
                          ref.read(loopSessionControllerProvider).markInit(),
                        ),
                  icon: Icon(hasInit ? Icons.check_circle : Icons.my_location),
                  label: Text(
                    hasInit ? l10n.loopInitSet : l10n.markLoopInitHere,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                return OutlinedButton.icon(
                  onPressed: hasInit && !hasEnd
                      ? () => _runLoopAction(
                          context,
                          ref.read(loopSessionControllerProvider).markEnd(),
                        )
                      : null,
                  icon: const Icon(Icons.sports_score),
                  label: Text(l10n.markLoopEndHere),
                );
              },
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onEndSession,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppTheme.signal),
              foregroundColor: AppTheme.signal,
            ),
            child: Text(l10n.endSession),
          ),
        ],
      ),
    );
  }
}

class _StartErrorBody extends StatelessWidget {
  const _StartErrorBody({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final String error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Icon(Icons.gps_off, size: 48, color: AppTheme.signal),
          const SizedBox(height: 16),
          Text(
            l10n.couldNotStart,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 15),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            child: Text(l10n.tryAgain),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onBack,
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.exo2(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
