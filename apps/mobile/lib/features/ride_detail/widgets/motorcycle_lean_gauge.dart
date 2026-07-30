import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Motorcycle lean gauge: 0° upright, left / right bank.
class MotorcycleLeanGauge extends StatelessWidget {
  const MotorcycleLeanGauge({
    super.key,
    required this.leanDegrees,
    required this.maxLeftDegrees,
    required this.maxRightDegrees,
    this.neutralLabel,
    this.height = 210,
  });

  /// Relative lean: negative = left, positive = right.
  final double leanDegrees;
  final double maxLeftDegrees;
  final double maxRightDegrees;
  final String? neutralLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final absLean = leanDegrees.abs().clamp(0, 70);
    final side = leanDegrees < -1
        ? 'LEFT'
        : leanDegrees > 1
            ? 'RIGHT'
            : 'UPRIGHT';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3036), Color(0xFF171A1D)],
        ),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'BIKE LEAN',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.steel,
                ),
              ),
              const Spacer(),
              if (neutralLabel != null)
                Text(
                  neutralLabel!,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppTheme.steel,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _LeanGaugePainter(
                leanDegrees: leanDegrees.clamp(-70, 70),
                maxLeft: maxLeftDegrees.clamp(0, 70),
                maxRight: maxRightDegrees.clamp(0, 70),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${absLean.toStringAsFixed(0)}° $side',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: side == 'LEFT'
                  ? AppTheme.line
                  : side == 'RIGHT'
                      ? AppTheme.signal
                      : AppTheme.mist,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SidePeak(
                  label: 'MAX LEFT',
                  value: '${maxLeftDegrees.toStringAsFixed(0)}°',
                  color: AppTheme.line,
                  alignEnd: false,
                ),
              ),
              Expanded(
                child: _SidePeak(
                  label: 'MAX RIGHT',
                  value: '${maxRightDegrees.toStringAsFixed(0)}°',
                  color: AppTheme.signal,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidePeak extends StatelessWidget {
  const _SidePeak({
    required this.label,
    required this.value,
    required this.color,
    required this.alignEnd,
  });

  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            letterSpacing: 1.0,
            color: AppTheme.steel,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _LeanGaugePainter extends CustomPainter {
  _LeanGaugePainter({
    required this.leanDegrees,
    required this.maxLeft,
    required this.maxRight,
  });

  final double leanDegrees;
  final double maxLeft;
  final double maxRight;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.72);
    final radius = math.min(size.width * 0.42, size.height * 0.78);

    final track = Paint()
      ..color = AppTheme.mist.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Arc from -70° (left) to +70° (right), drawn above center.
    const start = -math.pi * 0.92;
    const sweep = math.pi * 0.84;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      track,
    );

    void paintPeak(double degrees, Color color, bool left) {
      if (degrees < 3) return;
      final t = (degrees / 70).clamp(0.0, 1.0);
      final ang = left
          ? start + (0.5 - t * 0.5) * sweep
          : start + (0.5 + t * 0.5) * sweep;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      final from = left ? ang : start + 0.5 * sweep;
      final to = left ? start + 0.5 * sweep : ang;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        from,
        to - from,
        false,
        paint,
      );
    }

    paintPeak(maxLeft, AppTheme.line, true);
    paintPeak(maxRight, AppTheme.signal, false);

    // Zero tick.
    final zeroAng = start + 0.5 * sweep;
    final z1 = Offset(
      center.dx + math.cos(zeroAng) * (radius - 18),
      center.dy + math.sin(zeroAng) * (radius - 18),
    );
    final z2 = Offset(
      center.dx + math.cos(zeroAng) * (radius + 18),
      center.dy + math.sin(zeroAng) * (radius + 18),
    );
    canvas.drawLine(
      z1,
      z2,
      Paint()
        ..color = AppTheme.mist.withValues(alpha: 0.55)
        ..strokeWidth = 2,
    );

    // Bike stick lean.
    final leanT = (leanDegrees / 70).clamp(-1.0, 1.0);
    final bikeAng = -math.pi / 2 + leanT * (math.pi * 0.42);
    final bikePaint = Paint()
      ..color = leanDegrees < -1
          ? AppTheme.line
          : leanDegrees > 1
              ? AppTheme.signal
              : AppTheme.mist
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final tip = Offset(
      center.dx + math.cos(bikeAng) * (radius * 0.62),
      center.dy + math.sin(bikeAng) * (radius * 0.62),
    );
    canvas.drawLine(center, tip, bikePaint);
    canvas.drawCircle(center, 7, Paint()..color = AppTheme.mist);
    canvas.drawCircle(tip, 5, bikePaint);

    // Labels L / R
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset at, Color color) {
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        at - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    label(
      'L',
      Offset(center.dx - radius * 0.85, center.dy - radius * 0.15),
      AppTheme.line,
    );
    label(
      'R',
      Offset(center.dx + radius * 0.85, center.dy - radius * 0.15),
      AppTheme.signal,
    );
    label(
      '0°',
      Offset(center.dx, center.dy - radius - 8),
      AppTheme.steel,
    );
  }

  @override
  bool shouldRepaint(covariant _LeanGaugePainter oldDelegate) {
    return oldDelegate.leanDegrees != leanDegrees ||
        oldDelegate.maxLeft != maxLeft ||
        oldDelegate.maxRight != maxRight;
  }
}
