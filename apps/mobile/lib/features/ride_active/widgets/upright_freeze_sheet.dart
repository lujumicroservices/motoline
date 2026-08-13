import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/lean_lab/lean_imu_math.dart';
import '../../../core/lean_lab/upright_freeze_controller.dart';
import '../../../core/services/lean_sensor.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';
import 'upright_freeze_panel.dart';

/// Tap while the phone is still in hand, pocket it, freeze g0, then arm.
Future<Vec3?> showUprightFreezeSheet(
  BuildContext context, {
  required String title,
  required String help,
}) {
  return showModalBottomSheet<Vec3>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.asphaltElevated,
    builder: (_) => _UprightFreezeSheet(title: title, help: help),
  );
}

/// Arm auto-start only after a pocket/tank freeze so 0° is captured in-mount.
Future<bool> freezeThenArm(
  BuildContext context,
  WidgetRef ref, {
  String? routeId,
}) async {
  final l10n = context.l10n;
  final g0 = await showUprightFreezeSheet(
    context,
    title: l10n.armAutoRide,
    help: l10n.freezeThenArmHelp,
  );
  if (g0 == null || !context.mounted) return false;
  ref.read(rideRecorderProvider).prepareLeanLabUpright(g0);
  await ref.read(armedStateProvider.notifier).arm(routeId: routeId);
  return true;
}

class _UprightFreezeSheet extends StatefulWidget {
  const _UprightFreezeSheet({required this.title, required this.help});

  final String title;
  final String help;

  @override
  State<_UprightFreezeSheet> createState() => _UprightFreezeSheetState();
}

class _UprightFreezeSheetState extends State<_UprightFreezeSheet> {
  final LeanSensor _sensor = LeanSensor();
  late final UprightFreezeController _freeze;

  @override
  void initState() {
    super.initState();
    _sensor.start();
    _freeze = UprightFreezeController(
      _sensor.engine,
      onFrozen: (g0, {required bool fromPocket}) {
        if (!mounted) return;
        Navigator.of(context).pop(g0);
      },
    )..attach();
    _freeze.addListener(_onTick);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _freeze.removeListener(_onTick);
    _freeze.dispose();
    _sensor.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.help,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            UprightFreezePanel(controller: _freeze),
            TextButton(
              onPressed: _freeze.busy
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
