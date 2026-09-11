import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

enum SessionMotionCueMode { waiting, held, live }

/// Status strip under GPS: waiting, recording-in-motion, or detection-off.
class SessionMotionCue extends StatefulWidget {
  const SessionMotionCue({super.key, required this.mode});

  final SessionMotionCueMode mode;

  @override
  State<SessionMotionCue> createState() => _SessionMotionCueState();
}

class _SessionMotionCueState extends State<SessionMotionCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _radar;

  bool get _animate =>
      widget.mode == SessionMotionCueMode.waiting ||
      widget.mode == SessionMotionCueMode.live;

  Duration get _period => widget.mode == SessionMotionCueMode.live
      ? const Duration(milliseconds: 900)
      : const Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(vsync: this, duration: _period);
    if (_animate) _radar.repeat();
  }

  @override
  void didUpdateWidget(covariant SessionMotionCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _radar.duration = _period;
    }
    if (_animate) {
      if (!_radar.isAnimating) _radar.repeat();
    } else if (_radar.isAnimating) {
      _radar.stop();
      _radar.value = 0;
    }
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = widget.mode;
    final accent = switch (mode) {
      SessionMotionCueMode.held => AppTheme.steel,
      SessionMotionCueMode.waiting => AppTheme.lineHot,
      SessionMotionCueMode.live => AppTheme.line,
    };
    final title = switch (mode) {
      SessionMotionCueMode.held => l10n.sessionNotDetectingMotion,
      SessionMotionCueMode.waiting => l10n.sessionWaitingMotion,
      SessionMotionCueMode.live => l10n.sessionRecordingMotion,
    };
    final subtitle = switch (mode) {
      SessionMotionCueMode.held => l10n.sessionNotDetectingMotionHelp,
      SessionMotionCueMode.waiting => l10n.sessionWaitingMotionHelp,
      SessionMotionCueMode.live => l10n.sessionRecordingMotionHelp,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: mode == SessionMotionCueMode.held
                ? _HeldGlyph(color: accent)
                : AnimatedBuilder(
                    animation: _radar,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _RadarPainter(
                          t: _radar.value,
                          color: accent,
                          filledCore: mode == SessionMotionCueMode.live,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.two_wheeler,
                            size: 22,
                            color: mode == SessionMotionCueMode.live
                                ? AppTheme.asphalt
                                : accent,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.mist,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldGlyph extends StatelessWidget {
  const _HeldGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Icon(Icons.sensors_off, color: color, size: 26),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.color,
    this.filledCore = false,
  });

  final double t;
  final Color color;
  final bool filledCore;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      final r = 12 + (maxR - 12) * p;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = filledCore ? 2 : 1.6
          ..color = color.withValues(alpha: (1 - p) * 0.55),
      );
    }
    if (filledCore) {
      canvas.drawCircle(center, 16, Paint()..color = color);
    } else {
      canvas.drawCircle(
        center,
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.color != color ||
      oldDelegate.filledCore != filledCore;
}
