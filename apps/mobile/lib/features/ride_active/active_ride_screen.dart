import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/track_point.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../ride_detail/pilot_line_map.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'widgets/gps_status_widgets.dart';

class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key, this.autoStart = true});

  /// When true, starts the recorder (with GPS warm-up UI) on open.
  final bool autoStart;

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  Timer? _tick;
  bool _starting = false;
  GnssWarmupStatus? _warmup;
  Object? _startError;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
    }
  }

  Future<void> _bootstrap() async {
    final recorder = ref.read(rideRecorderProvider);
    if (recorder.isRecording) return;

    setState(() {
      _starting = true;
      _startError = null;
      _warmup = const GnssWarmupStatus(
        phase: GpsWarmupPhase.permissions,
        message: 'Checking location permission…',
      );
    });

    try {
      await recorder.start(
        onWarmup: (status) {
          if (!mounted) return;
          setState(() => _warmup = status);
        },
      );
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

    return PopScope(
      canPop: !_starting && !recorder.isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_starting) return;
        // Recording: use End ride.
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_starting ? l10n.starting : l10n.recording),
          automaticallyImplyLeading: false,
          leading: (_starting || recorder.isRecording)
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          actions: [
            if (!_starting && recorder.isRecording)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.signal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.signal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.live,
                          style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.signal,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: _starting
            ? GpsWarmupPanel(
                status: _warmup ??
                    const GnssWarmupStatus(
                      phase: GpsWarmupPhase.searching,
                      message: 'Preparing high-precision GPS…',
                    ),
              )
            : _startError != null
                ? _StartErrorBody(
                    error: '$_startError',
                    onRetry: _bootstrap,
                    onBack: () => Navigator.of(context).pop(),
                  )
                : snapshotAsync.when(
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
                      );
                    },
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
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 13),
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
            child: PilotLineMap(
              points: points,
              interactive: false,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.signal,
              minimumSize: const Size.fromHeight(56),
            ),
            onPressed: () => _stop(context),
            child: Text(l10n.endRide),
          ),
        ),
      ],
    );
  }

  Future<void> _stop(BuildContext context) async {
    final recorder = ref.read(rideRecorderProvider);
    try {
      final ride = await recorder.stop();
      // Closed beta: share with friends (soft-fail offline).
      unawaited(ref.read(rideSyncServiceProvider).syncRide(ride.id));
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RideDetailScreen(rideId: ride.id),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
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
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppTheme.steel, fontSize: 15),
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
            style: GoogleFonts.outfit(
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
                style: GoogleFonts.spaceGrotesk(
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
