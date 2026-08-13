import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/lean_lab/upright_freeze_controller.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// One button: tap, mount the phone, freeze on stillness, then auto-start.
class UprightFreezePanel extends StatelessWidget {
  const UprightFreezePanel({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final UprightFreezeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    final busy = c.busy;
    final status = switch (c.phase) {
      UprightFreezePhase.countdown =>
        l10n.leanLabCalibPocketCountdown(c.countdownLeft),
      UprightFreezePhase.settle => l10n.leanLabCalibPocketSettle,
      UprightFreezePhase.capture => l10n.leanLabCalibPocketCapture,
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
        FilledButton.icon(
          onPressed: busy ? null : c.beginPlace,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(compact ? 56 : 72),
          ),
          icon: Icon(busy ? Icons.hourglass_top : Icons.play_arrow_rounded),
          label: Text(l10n.leanLabCalibPocket),
        ),
      ],
    );
  }
}
