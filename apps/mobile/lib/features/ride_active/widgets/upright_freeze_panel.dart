import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/lean_lab/upright_freeze_controller.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// Tank hold + pocket countdown buttons. Same ritual on ride deck, arm, lab.
class UprightFreezePanel extends StatelessWidget {
  const UprightFreezePanel({
    super.key,
    required this.controller,
    this.compact = false,
    this.showTank = true,
    this.showPocket = true,
  });

  final UprightFreezeController controller;
  final bool compact;
  final bool showTank;
  final bool showPocket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    final busy = c.busy;
    final status = switch (c.phase) {
      UprightFreezePhase.holding => l10n.leanLabCalibHolding,
      UprightFreezePhase.pocketCountdown =>
        l10n.leanLabCalibPocketCountdown(c.countdownLeft),
      UprightFreezePhase.pocketSettle => l10n.leanLabCalibPocketSettle,
      UprightFreezePhase.pocketCapture => l10n.leanLabCalibPocketCapture,
      UprightFreezePhase.failed => l10n.leanLabCalibPocketFail,
      UprightFreezePhase.done => l10n.leanLabFrozenNeutral,
      UprightFreezePhase.idle => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status != null) ...[
          Text(
            status,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              color: c.phase == UprightFreezePhase.failed
                  ? AppTheme.signal
                  : AppTheme.line,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 16 : 18,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (showPocket)
          FilledButton.icon(
            onPressed: busy ? null : c.beginPocket,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 56 : 64),
            ),
            icon: Icon(busy ? Icons.hourglass_top : Icons.move_to_inbox),
            label: Text(
              busy && c.phase != UprightFreezePhase.holding
                  ? (status ?? l10n.leanLabCalibPocket)
                  : l10n.leanLabCalibPocket,
            ),
          ),
        if (showPocket && showTank) const SizedBox(height: 8),
        if (showTank)
          FilledButton.tonalIcon(
            onPressed: busy ? null : c.beginTankHold,
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 52 : 56),
            ),
            icon: Icon(
              busy && c.phase == UprightFreezePhase.holding
                  ? Icons.hourglass_top
                  : Icons.vertical_align_center,
            ),
            label: Text(
              c.phase == UprightFreezePhase.holding
                  ? l10n.leanLabCalibHolding
                  : l10n.leanLabCalibHold,
            ),
          ),
      ],
    );
  }
}
