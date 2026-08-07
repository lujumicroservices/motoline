import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lean_lab/lean_lab_circuit.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/services/lean_sensor.dart';
import '../../core/telemetry/labels/ride_engine_label.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../home/home_nav_icons.dart';
import '../ride_active/active_ride_screen.dart';
import '../ride_detail/widgets/motorcycle_lean_gauge.dart';
import 'lean_lab_bootstrap.dart';

/// Pre-ride ritual: mount, pose, direction, upright calib → start recording.
class LeanLabPrepScreen extends ConsumerStatefulWidget {
  const LeanLabPrepScreen({super.key, required this.sessionType});

  final LeanLabSessionType sessionType;

  @override
  ConsumerState<LeanLabPrepScreen> createState() => _LeanLabPrepScreenState();
}

class _LeanLabPrepScreenState extends ConsumerState<LeanLabPrepScreen> {
  late String _mount;
  late PhonePoseId _pose;
  late LeanLabDirection _direction;
  final LeanSensor _sensor = LeanSensor();
  Timer? _tick;
  bool _holding = false;
  double? _frozenNeutral;
  DateTime? _calibAt;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _mount = LeanLabService.defaultMount(widget.sessionType);
    _pose = PhonePoseId.portraitScreenOut;
    _direction = LeanLabService.defaultDirection(widget.sessionType);
    _sensor.start();
    _tick = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      if (_holding) _sensor.sampleForManualCalib();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _sensor.stop();
    super.dispose();
  }

  Future<void> _runHold() async {
    setState(() {
      _holding = true;
      _frozenNeutral = null;
    });
    _sensor.clearCalibBuffer();
    await Future<void>.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    final n = _sensor.peekCalibNeutral(minSamples: 20) ??
        _sensor.rawLeanDegrees;
    setState(() {
      _holding = false;
      _frozenNeutral = n;
      _calibAt = DateTime.now();
    });
  }

  Future<void> _startRide() async {
    final neutral = _frozenNeutral;
    if (neutral == null) return;
    setState(() => _starting = true);
    final recorder = ref.read(rideRecorderProvider);
    recorder.prepareLeanLabNeutral(neutral);
    _sensor.stop();
    try {
      // Navigate to active ride; it starts recording via autoStart.
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ActiveRideScreen(
            autoStart: true,
            leanLabBootstrap: LeanLabRideBootstrap(
              sessionType: widget.sessionType,
              direction: _direction,
              phoneMount: _mount,
              phonePose: _pose,
              frozenNeutralDeg: neutral,
              calibAt: _calibAt,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lean = _sensor.leanDegrees ?? 0;
    final raw = _sensor.rawLeanDegrees;

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanLabPrepTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l10n.leanLabPrepHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.engineLabelMountQ,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in [
                PhoneMountId.centerMount,
                PhoneMountId.leftPocket,
                PhoneMountId.rightPocket,
                PhoneMountId.other,
              ])
                ChoiceChip(
                  label: Text(_mountLabel(l10n, m)),
                  selected: _mount == m,
                  onSelected: (_) => setState(() => _mount = m),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.leanLabPoseQ,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in PhonePoseId.values)
                ChoiceChip(
                  label: Text(_poseLabel(l10n, p)),
                  selected: _pose == p,
                  onSelected: (_) => setState(() => _pose = p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.leanLabDirectionQ,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.leanLabDirectionOutbound),
                selected: _direction == LeanLabDirection.outbound,
                onSelected: (_) =>
                    setState(() => _direction = LeanLabDirection.outbound),
              ),
              ChoiceChip(
                label: Text(l10n.leanLabDirectionReturn),
                selected: _direction == LeanLabDirection.returnTrip,
                onSelected: (_) =>
                    setState(() => _direction = LeanLabDirection.returnTrip),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.leanLabCalibTitle,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            l10n.leanLabCalibHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          MotorcycleLeanGauge(
            leanDegrees: lean,
            maxLeftDegrees: 25,
            maxRightDegrees: 25,
            height: 130,
          ),
          const SizedBox(height: 8),
          Text(
            raw == null
                ? '…'
                : '${l10n.leanLabRawNeutral}: ${raw.toStringAsFixed(1)}°',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
          ),
          if (_frozenNeutral != null)
            Text(
              '${l10n.leanLabFrozenNeutral}: ${_frozenNeutral!.toStringAsFixed(1)}°',
              style: GoogleFonts.exo2(
                color: AppTheme.line,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _holding ? null : _runHold,
            icon: Icon(_holding ? Icons.hourglass_top : Icons.vertical_align_center),
            label: Text(
              _holding ? l10n.leanLabCalibHolding : l10n.leanLabCalibHold,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _frozenNeutral == null || _starting ? null : _startRide,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const AppMotoIcon(size: 22),
            label: Text(l10n.leanLabStartRide),
          ),
        ],
      ),
    );
  }

  String _mountLabel(AppLocalizations l10n, String id) => switch (id) {
        PhoneMountId.centerMount => l10n.engineLabelMountCenter,
        PhoneMountId.leftPocket => l10n.engineLabelMountLeftPocket,
        PhoneMountId.rightPocket => l10n.engineLabelMountRightPocket,
        _ => l10n.engineLabelMountOther,
      };

  String _poseLabel(AppLocalizations l10n, PhonePoseId p) => switch (p) {
        PhonePoseId.portraitScreenOut => l10n.leanLabPoseScreenOut,
        PhonePoseId.portraitScreenIn => l10n.leanLabPoseScreenIn,
        PhonePoseId.landscape => l10n.leanLabPoseLandscape,
        PhonePoseId.other => l10n.engineLabelMountOther,
      };
}
