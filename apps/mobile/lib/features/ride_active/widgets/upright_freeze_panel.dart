import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/lean_lab/upright_freeze_controller.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// One button: arm freeze (pocket place or hold-in-mount), then auto-start.
class UprightFreezePanel extends StatelessWidget {
  const UprightFreezePanel({
    super.key,
    required this.controller,
    this.mode = UprightFreezeMode.place,
    this.compact = false,
  });

  final UprightFreezeController controller;
  final UprightFreezeMode mode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    final busy = c.busy;

    String? status;
    switch (c.phase) {
      case UprightFreezePhase.countdown:
        status = l10n.leanLabCalibPocketCountdown(c.countdownLeft);
      case UprightFreezePhase.settle:
        status = l10n.leanLabCalibPocketSettle;
      case UprightFreezePhase.capture:
        status = c.mode == UprightFreezeMode.hold
            ? l10n.leanLabCalibHolding
            : l10n.leanLabCalibPocketCapture;
      case UprightFreezePhase.failed:
        status = l10n.leanLabCalibPocketFail;
      case UprightFreezePhase.done:
        status = l10n.leanLabFrozenNeutral;
      case UprightFreezePhase.idle:
        status = null;
    }

    final label = mode == UprightFreezeMode.hold
        ? l10n.leanLabCalibHold
        : l10n.leanLabCalibPocket;

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
        FilledButton.icon(
          onPressed: busy ? null : () => c.begin(mode),
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? 56 : 72),
          ),
          icon: Icon(busy ? Icons.hourglass_top : Icons.play_arrow_rounded),
          label: Text(label),
        ),
      ],
    );
  }
}
