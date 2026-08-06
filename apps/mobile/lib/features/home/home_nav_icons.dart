import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Glove-friendly home nav button with a unique glyph (not generic Material).
class HomeNavIconButton extends StatelessWidget {
  const HomeNavIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.painter,
    this.icon,
  }) : assert(painter != null || icon != null);

  final String tooltip;
  final VoidCallback onPressed;
  final CustomPainter? painter;
  final IconData? icon;

  static const double hit = 52;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: hit, minHeight: hit),
      onPressed: onPressed,
      icon: icon != null
          ? Icon(icon, size: 28, color: AppTheme.mist)
          : SizedBox(
              width: 34,
              height: 34,
              child: CustomPaint(painter: painter!),
            ),
    );
  }
}

/// Three distinct motorcycles riding — Rodadas pack icon.
class RodadaPackIconPainter extends CustomPainter {
  const RodadaPackIconPainter({this.color = AppTheme.mist});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: 0.92);

    // Back-left: upright / adventure (taller, longer wheelbase feel).
    _adventureBike(
      canvas,
      origin: Offset(size.width * 0.02, size.height * 0.58),
      scale: 0.72,
      stroke: stroke,
      fill: fill,
    );
    // Back-right: cruiser (low seat, fat rear wheel hint).
    _cruiserBike(
      canvas,
      origin: Offset(size.width * 0.38, size.height * 0.62),
      scale: 0.70,
      stroke: stroke,
      fill: fill,
    );
    // Lead: sport bike (tucked, sharp nose) — front / center.
    _sportBike(
      canvas,
      origin: Offset(size.width * 0.22, size.height * 0.28),
      scale: 0.92,
      stroke: stroke,
      fill: fill,
    );
  }

  void _wheels(
    Canvas canvas, {
    required Offset rear,
    required Offset front,
    required double rRear,
    required double rFront,
    required Paint stroke,
  }) {
    canvas.drawCircle(rear, rRear, stroke);
    canvas.drawCircle(front, rFront, stroke);
  }

  void _riderTuck(
    Canvas canvas, {
    required Offset seat,
    required double scale,
    required Paint stroke,
    required Paint fill,
    double lean = -0.15,
  }) {
    final head = Offset(
      seat.dx + 5.5 * scale * math.cos(lean),
      seat.dy - 7.5 * scale + 2 * scale * math.sin(lean),
    );
    canvas.drawCircle(head, 2.4 * scale, fill);
    canvas.drawLine(
      Offset(seat.dx + 1 * scale, seat.dy - 1 * scale),
      head,
      stroke,
    );
    // Arms toward bars.
    canvas.drawLine(
      Offset(seat.dx + 1.5 * scale, seat.dy - 2 * scale),
      Offset(seat.dx + 9 * scale, seat.dy - 3.5 * scale),
      stroke,
    );
  }

  /// Sharp fairing, short wheelbase vibe.
  void _sportBike(
    Canvas canvas, {
    required Offset origin,
    required double scale,
    required Paint stroke,
    required Paint fill,
  }) {
    final rear = Offset(origin.dx + 3 * scale, origin.dy + 14 * scale);
    final front = Offset(origin.dx + 22 * scale, origin.dy + 14 * scale);
    _wheels(
      canvas,
      rear: rear,
      front: front,
      rRear: 3.4 * scale,
      rFront: 3.2 * scale,
      stroke: stroke,
    );
    // Swingarm + frame diamond.
    canvas.drawLine(rear, Offset(origin.dx + 10 * scale, origin.dy + 8 * scale), stroke);
    canvas.drawLine(
      Offset(origin.dx + 10 * scale, origin.dy + 8 * scale),
      Offset(origin.dx + 17 * scale, origin.dy + 7 * scale),
      stroke,
    );
    canvas.drawLine(
      Offset(origin.dx + 17 * scale, origin.dy + 7 * scale),
      front,
      stroke,
    );
    // Tail + seat.
    canvas.drawLine(
      Offset(origin.dx + 2 * scale, origin.dy + 9 * scale),
      Offset(origin.dx + 11 * scale, origin.dy + 7.5 * scale),
      stroke,
    );
    // Fairing / nose.
    final fairing = Path()
      ..moveTo(origin.dx + 15 * scale, origin.dy + 6 * scale)
      ..lineTo(origin.dx + 23 * scale, origin.dy + 5 * scale)
      ..lineTo(origin.dx + 20 * scale, origin.dy + 9 * scale)
      ..close();
    canvas.drawPath(fairing, stroke);
    _riderTuck(
      canvas,
      seat: Offset(origin.dx + 9 * scale, origin.dy + 7 * scale),
      scale: scale,
      stroke: stroke,
      fill: fill,
      lean: -0.25,
    );
  }

  /// Tall screen / upright bars.
  void _adventureBike(
    Canvas canvas, {
    required Offset origin,
    required double scale,
    required Paint stroke,
    required Paint fill,
  }) {
    final rear = Offset(origin.dx + 3 * scale, origin.dy + 13 * scale);
    final front = Offset(origin.dx + 20 * scale, origin.dy + 13 * scale);
    _wheels(
      canvas,
      rear: rear,
      front: front,
      rRear: 3.6 * scale,
      rFront: 3.6 * scale,
      stroke: stroke,
    );
    canvas.drawLine(rear, Offset(origin.dx + 9 * scale, origin.dy + 6 * scale), stroke);
    canvas.drawLine(
      Offset(origin.dx + 9 * scale, origin.dy + 6 * scale),
      Offset(origin.dx + 15 * scale, origin.dy + 5.5 * scale),
      stroke,
    );
    canvas.drawLine(
      Offset(origin.dx + 15 * scale, origin.dy + 5.5 * scale),
      front,
      stroke,
    );
    // Tall windshield.
    canvas.drawLine(
      Offset(origin.dx + 15 * scale, origin.dy + 5.5 * scale),
      Offset(origin.dx + 16.5 * scale, origin.dy + 1.2 * scale),
      stroke,
    );
    // High bars.
    canvas.drawLine(
      Offset(origin.dx + 14 * scale, origin.dy + 5 * scale),
      Offset(origin.dx + 18 * scale, origin.dy + 3 * scale),
      stroke,
    );
    // Upright rider.
    final seat = Offset(origin.dx + 8 * scale, origin.dy + 5.5 * scale);
    final head = Offset(seat.dx + 2 * scale, seat.dy - 8 * scale);
    canvas.drawCircle(head, 2.3 * scale, fill);
    canvas.drawLine(seat, head, stroke);
    canvas.drawLine(
      Offset(seat.dx + 1 * scale, seat.dy - 3 * scale),
      Offset(origin.dx + 17 * scale, origin.dy + 3.5 * scale),
      stroke,
    );
  }

  /// Low long silhouette, bigger rear hoop.
  void _cruiserBike(
    Canvas canvas, {
    required Offset origin,
    required double scale,
    required Paint stroke,
    required Paint fill,
  }) {
    final rear = Offset(origin.dx + 4 * scale, origin.dy + 13 * scale);
    final front = Offset(origin.dx + 23 * scale, origin.dy + 13 * scale);
    _wheels(
      canvas,
      rear: rear,
      front: front,
      rRear: 4.0 * scale,
      rFront: 3.0 * scale,
      stroke: stroke,
    );
    // Low frame.
    canvas.drawLine(
      Offset(rear.dx, rear.dy - 2 * scale),
      Offset(origin.dx + 14 * scale, origin.dy + 9 * scale),
      stroke,
    );
    canvas.drawLine(
      Offset(origin.dx + 14 * scale, origin.dy + 9 * scale),
      Offset(front.dx - 1 * scale, front.dy - 1 * scale),
      stroke,
    );
    // Long seat / fender.
    canvas.drawLine(
      Offset(origin.dx + 3 * scale, origin.dy + 8.5 * scale),
      Offset(origin.dx + 13 * scale, origin.dy + 8 * scale),
      stroke,
    );
    // Forward controls / footpeg hint.
    canvas.drawLine(
      Offset(origin.dx + 12 * scale, origin.dy + 9 * scale),
      Offset(origin.dx + 16 * scale, origin.dy + 12 * scale),
      stroke,
    );
    // Relaxed rider.
    final seat = Offset(origin.dx + 9 * scale, origin.dy + 7.5 * scale);
    final head = Offset(seat.dx + 3 * scale, seat.dy - 6.5 * scale);
    canvas.drawCircle(head, 2.2 * scale, fill);
    canvas.drawLine(seat, head, stroke);
    canvas.drawLine(
      Offset(seat.dx + 1 * scale, seat.dy - 2 * scale),
      Offset(origin.dx + 18 * scale, origin.dy + 8 * scale),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant RodadaPackIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Simple circuit ribbon — only shown when routes feature is on.
class RoutesRibbonIconPainter extends CustomPainter {
  const RoutesRibbonIconPainter({this.color = AppTheme.mist});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.18,
        size.width * 0.55,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.72,
        size.width * 0.88,
        size.height * 0.28,
      );
    canvas.drawPath(path, stroke);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * 0.72),
      2.4,
      Paint()..color = color,
    );
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.28),
      2.4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant RoutesRibbonIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
