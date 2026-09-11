import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

/// Compact pause/resume detection + finish session controls.
class SessionActionBar extends StatelessWidget {
  const SessionActionBar({
    super.key,
    required this.held,
    required this.onToggleHold,
    required this.onFinish,
  });

  final bool held;
  final VoidCallback onToggleHold;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppTheme.asphalt,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.mist.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BarSlot(
                    tooltip: held
                        ? l10n.resumeMotionDetection
                        : l10n.pauseMotionDetection,
                    onPressed: onToggleHold,
                    child: Icon(
                      held ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 30,
                      color: held ? AppTheme.lineHot : AppTheme.mist,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.steel.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: _BarSlot(
                    tooltip: l10n.endSession,
                    onPressed: onFinish,
                    child: const CheckeredFlagIcon(
                      size: 26,
                      color: AppTheme.signal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BarSlot extends StatelessWidget {
  const _BarSlot({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Center(child: child),
      ),
    );
  }
}

/// Racing finish flag: 4×3 checkerboard.
class CheckeredFlagIcon extends StatelessWidget {
  const CheckeredFlagIcon({
    super.key,
    this.size = 24,
    this.color = AppTheme.mist,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CheckeredFlagPainter(color)),
    );
  }
}

class _CheckeredFlagPainter extends CustomPainter {
  _CheckeredFlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pole = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.08),
      Offset(size.width * 0.12, size.height * 0.92),
      pole,
    );

    const cols = 4;
    const rows = 3;
    final left = size.width * 0.2;
    final top = size.height * 0.1;
    final flagW = size.width * 0.74;
    final flagH = size.height * 0.58;
    final cellW = flagW / cols;
    final cellH = flagH / rows;
    final fill = Paint()..color = color;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r + c).isEven) {
          canvas.drawRect(
            Rect.fromLTWH(left + c * cellW, top + r * cellH, cellW, cellH),
            fill,
          );
        }
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(left, top, flagW, flagH),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckeredFlagPainter oldDelegate) =>
      oldDelegate.color != color;
}
