import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/lean_lab/lean_imu_math.dart';
import '../../core/lean_lab/lean_lab_circuit.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../core/lean_lab/upright_freeze_controller.dart';
import '../../core/services/lean_engine.dart';
import '../../core/services/lean_sensor.dart';
import '../../core/telemetry/labels/ride_engine_label.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../home/home_nav_icons.dart';
import '../ride_active/active_ride_screen.dart';
import '../ride_active/widgets/upright_freeze_panel.dart';
import '../ride_detail/widgets/motorcycle_lean_gauge.dart';
import 'lean_lab_bootstrap.dart';

/// Pre-ride ritual: mount, pose, direction, upright g0 freeze → start recording.
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
  late final UprightFreezeController _freeze;
  double? _frozenNeutral;
  Vec3? _frozenG0;
  DateTime? _calibAt;
  bool _starting = false;

  bool get _isPocket =>
      _mount == PhoneMountId.leftPocket || _mount == PhoneMountId.rightPocket;

  int get _signFlip => _pose == PhonePoseId.portraitScreenIn ? -1 : 1;

  @override
  void initState() {
    super.initState();
    _mount = LeanLabService.defaultMount(widget.sessionType);
    _pose = PhonePoseId.portraitScreenOut;
    _direction = LeanLabService.defaultDirection(widget.sessionType);
    _sensor.start();
    _freeze = UprightFreezeController(
      _sensor.engine,
      signFlip: _signFlip,
      onFrozen: (g0, {required bool fromPocket}) {
        _frozenG0 = g0;
        _frozenNeutral = 0;
        _calibAt = DateTime.now();
        if (fromPocket) unawaited(_startRide());
        if (mounted) setState(() {});
      },
    )..attach();
    _freeze.addListener(_onFreeze);
    _sensor.engine.addListener(_onFreeze);
  }

  void _onFreeze() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _freeze.removeListener(_onFreeze);
    _sensor.engine.removeListener(_onFreeze);
    _freeze.dispose();
    _sensor.stop();
    super.dispose();
  }

  Future<void> _startRide() async {
    final g0 = _frozenG0;
    if (g0 == null) return;
    setState(() => _starting = true);
    final recorder = ref.read(rideRecorderProvider);
    recorder.prepareLeanLabUpright(g0, signFlip: _signFlip);
    recorder.prepareLeanLabNeutral(0);
    _sensor.stop();
    try {
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
              frozenNeutralDeg: 0,
              frozenG0: g0,
              signFlip: _signFlip,
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
    final snap = _sensor.snapshot;
    final lean = snap?.bikeLean ?? 0;
    final busy = _freeze.busy;
    _freeze.signFlip = _signFlip;

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
                  onSelected: busy
                      ? null
                      : (_) => setState(() => _mount = m),
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
                  onSelected: busy
                      ? null
                      : (_) => setState(() => _pose = p),
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
                onSelected: busy
                    ? null
                    : (_) =>
                        setState(() => _direction = LeanLabDirection.outbound),
              ),
              ChoiceChip(
                label: Text(l10n.leanLabDirectionReturn),
                selected: _direction == LeanLabDirection.returnTrip,
                onSelected: busy
                    ? null
                    : (_) =>
                        setState(() => _direction = LeanLabDirection.returnTrip),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l10n.leanLabCalibTitle,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            _isPocket ? l10n.leanLabCalibPocketHelp : l10n.leanLabCalibHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (snap != null) _PoseBanner(snap: snap, frozen: _frozenG0 != null),
          const SizedBox(height: 12),
          MotorcycleLeanGauge(
            leanDegrees: lean,
            maxLeftDegrees: 25,
            maxRightDegrees: 25,
            height: 130,
          ),
          const SizedBox(height: 8),
          Text(
            snap == null
                ? '…'
                : '${l10n.leanLabRawNeutral}: ${snap.vectorLean.toStringAsFixed(1)}°',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12),
          ),
          if (_frozenG0 != null)
            Text(
              '${l10n.leanLabFrozenNeutral}: ${_frozenG0!.toString()} · ${snap?.pose.label ?? ''}',
              style: GoogleFonts.exo2(
                color: AppTheme.line,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          UprightFreezePanel(
            controller: _freeze,
            showPocket: _isPocket,
            showTank: !_isPocket,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _frozenNeutral == null || _starting || busy
                ? null
                : _startRide,
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

class _PoseBanner extends StatelessWidget {
  const _PoseBanner({required this.snap, required this.frozen});

  final LeanEngineSnapshot snap;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final pose = snap.pose;
    final warn = frozen &&
        pose == PhonePoseClass.verticalY &&
        snap.tilt > 8;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warn ? AppTheme.signal : AppTheme.line.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${pose.label} · ${snap.winningChannel}  ·  ${snap.upAxis}'
            '${snap.trackerConfidence > 0 ? '  ·  conf ${snap.trackerConfidence.toStringAsFixed(2)}' : ''}',
            style: GoogleFonts.exo2(
              color: AppTheme.mist,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (warn)
            Text(
              context.l10n.leanLabFreezeRedo(snap.tilt.toStringAsFixed(0)),
              style: GoogleFonts.rajdhani(
                color: AppTheme.signal,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
