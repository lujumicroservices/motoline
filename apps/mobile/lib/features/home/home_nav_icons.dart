import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Glove-friendly home nav button with a unique glyph (not generic Material).
class HomeNavIconButton extends StatelessWidget {
  const HomeNavIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.painter,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final CustomPainter painter;

  static const double hit = 52;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: hit, minHeight: hit),
      onPressed: onPressed,
      icon: SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(painter: painter),
      ),
    );
  }
}

/// Pack of three riders — Rodadas (group ride), not a generic “groups” icon.
class RodadaPackIconPainter extends CustomPainter {
  const RodadaPackIconPainter({this.color = AppTheme.mist});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: 0.9);

    void helmet(Offset c, double r) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi * 1.05,
        math.pi * 1.1,
        false,
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - r * 0.85, c.dy + r * 0.15),
        Offset(c.dx + r * 0.85, c.dy + r * 0.15),
        stroke,
      );
      canvas.drawCircle(Offset(c.dx, c.dy - r * 0.15), r * 0.18, fill);
    }

    void bike(Offset rear, double scale) {
      final wheel = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(rear, 3.2 * scale, wheel);
      canvas.drawCircle(
        Offset(rear.dx + 11 * scale, rear.dy),
        3.2 * scale,
        wheel,
      );
      canvas.drawLine(
        Offset(rear.dx + 1 * scale, rear.dy - 1),
        Offset(rear.dx + 6 * scale, rear.dy - 5.5 * scale),
        stroke,
      );
      canvas.drawLine(
        Offset(rear.dx + 6 * scale, rear.dy - 5.5 * scale),
        Offset(rear.dx + 10 * scale, rear.dy - 1),
        stroke,
      );
    }

    final w = size.width;
    final h = size.height;
    // Lead + two wingmen — pack formation.
    helmet(Offset(w * 0.52, h * 0.28), w * 0.16);
    bike(Offset(w * 0.34, h * 0.72), 0.95);
    helmet(Offset(w * 0.22, h * 0.40), w * 0.13);
    bike(Offset(w * 0.08, h * 0.82), 0.78);
    helmet(Offset(w * 0.80, h * 0.40), w * 0.13);
    bike(Offset(w * 0.62, h * 0.82), 0.78);
  }

  @override
  bool shouldRepaint(covariant RodadaPackIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Two linked helmets — Friends, distinct from Rodadas pack.
class FriendsLinkIconPainter extends CustomPainter {
  const FriendsLinkIconPainter({this.color = AppTheme.mist});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: 0.85);

    void helmet(Offset c, double r) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi * 1.05,
        math.pi * 1.1,
        false,
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - r * 0.9, c.dy + r * 0.2),
        Offset(c.dx + r * 0.9, c.dy + r * 0.2),
        stroke,
      );
      canvas.drawCircle(Offset(c.dx + r * 0.15, c.dy - r * 0.1), r * 0.22, fill);
    }

    final w = size.width;
    final h = size.height;
    final left = Offset(w * 0.30, h * 0.42);
    final right = Offset(w * 0.70, h * 0.42);
    helmet(left, w * 0.20);
    helmet(right, w * 0.20);

    // Link arc between riders.
    final path = Path()
      ..moveTo(left.dx + w * 0.12, left.dy + h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.92, right.dx - w * 0.12, right.dy + h * 0.22);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(w * 0.5, h * 0.78), 2.2, fill);
  }

  @override
  bool shouldRepaint(covariant FriendsLinkIconPainter oldDelegate) =>
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

