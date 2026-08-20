import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'reel_highlights.dart';
import 'reel_timeline.dart';

class ReelFramePainter {
  ReelFramePainter({
    required this.highlights,
    required this.copy,
    required this.photos,
    ReelTimeline? timeline,
  }) : timeline = timeline ?? ReelTimeline();

  final ReelHighlights highlights;
  final ReelCopy copy;
  final List<ui.Image> photos;
  final ReelTimeline timeline;

  void paint(Canvas canvas, Size size, double timeSec) {
    final scene = timeline.sceneAt(timeSec);
    final t = scene.localT(timeSec);
    _paintBackground(canvas, size);

    switch (scene.kind) {
      case ReelSceneKind.hook:
        _paintHook(canvas, size, t);
      case ReelSceneKind.trail:
        _paintTrail(canvas, size, t, showHud: true);
      case ReelSceneKind.photos:
        _paintPhotos(canvas, size, t);
      case ReelSceneKind.stats:
        _paintStats(canvas, size, t);
      case ReelSceneKind.endCard:
        _paintEndCard(canvas, size, t);
    }
    _paintWatermark(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.asphalt,
    );
    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  void _paintHook(Canvas canvas, Size size, double t) {
    if (highlights.hookKind == 'photo' && photos.isNotEmpty) {
      _drawCoverPhoto(canvas, size, photos.first, zoom: 1 + 0.08 * t);
    } else {
      _paintTrail(canvas, size, 0.35, showHud: false);
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x990E1013),
    );
    final lean = highlights.maxLeanDeg.round();
    final scale = 0.72 + 0.28 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0));
    _drawCenteredText(
      canvas,
      size,
      '$lean°',
      fontSize: 168 * scale,
      color: AppTheme.signal,
      dy: -40,
      weight: FontWeight.w800,
    );
    _drawCenteredText(
      canvas,
      size,
      copy.hookSub.toUpperCase(),
      fontSize: 28,
      color: AppTheme.mist,
      dy: 90,
      letterSpacing: 4,
    );
  }

  void _paintTrail(Canvas canvas, Size size, double t, {required bool showHud}) {
    final trail = highlights.trail;
    if (trail.length < 2) return;
    final proj = _MapProject.fit(trail, size, padding: 72);
    final n = math.max(2, (trail.length * t.clamp(0.05, 1.0)).round());
    final pathPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 1; i < n; i++) {
      pathPaint.color = leanTrailColor(trail[i].leanAbs);
      canvas.drawLine(proj.offset(trail[i - 1]), proj.offset(trail[i]), pathPaint);
    }
    final head = proj.offset(trail[n - 1]);
    canvas.drawCircle(head, 11, Paint()..color = AppTheme.line);
    canvas.drawCircle(head, 5, Paint()..color = AppTheme.asphalt);

    for (final photo in highlights.photos) {
      final lat = photo.latitude;
      final lng = photo.longitude;
      if (lat == null || lng == null) continue;
      final o = proj.latLng(lat, lng);
      canvas.drawCircle(o, 7, Paint()..color = AppTheme.signal);
    }

    if (showHud) {
      _drawHudChip(
        canvas,
        size,
        top: 56,
        text: '${highlights.maxLeanDeg.round()}°  ·  ${highlights.distanceKm.toStringAsFixed(1)} km',
      );
    }
  }

  void _paintPhotos(Canvas canvas, Size size, double t) {
    if (photos.isEmpty) {
      _paintTrail(canvas, size, 1, showHud: true);
      return;
    }
    final idx = photos.length == 1
        ? 0
        : (t * photos.length).floor().clamp(0, photos.length - 1);
    final local = photos.length == 1
        ? t
        : (t * photos.length) - idx;
    _drawCoverPhoto(canvas, size, photos[idx], zoom: 1 + 0.12 * local);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 220, size.width, 220),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000E1013), Color(0xEE0E1013)],
        ).createShader(Rect.fromLTWH(0, size.height - 220, size.width, 220)),
    );
    _drawHudChip(
      canvas,
      size,
      top: size.height - 88,
      text: highlights.destination,
    );
  }

  void _paintStats(Canvas canvas, Size size, double t) {
    _paintTrail(canvas, size, 1, showHud: false);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xCC0E1013),
    );
    final items = <(String, String)>[
      (highlights.distanceKm.toStringAsFixed(1), copy.kmLabel),
      ('${highlights.curveCount}', copy.curvesLabel),
      ('${highlights.riderCount}', copy.ridersLabel),
      if (highlights.maxSpeedKmh != null)
        (highlights.maxSpeedKmh!.toStringAsFixed(0), copy.speedLabel),
    ];
    final appear = Curves.easeOutCubic.transform(t);
    var y = size.height * 0.22;
    for (var i = 0; i < items.length; i++) {
      final delay = (i * 0.12);
      final a = ((appear - delay) / 0.7).clamp(0.0, 1.0);
      if (a <= 0) continue;
      _drawCenteredText(
        canvas,
        size,
        items[i].$1,
        fontSize: 64,
        color: AppTheme.line,
        dy: y - size.height / 2,
        weight: FontWeight.w800,
      );
      _drawCenteredText(
        canvas,
        size,
        items[i].$2.toUpperCase(),
        fontSize: 18,
        color: AppTheme.steel,
        dy: y - size.height / 2 + 42,
        letterSpacing: 3,
      );
      y += 110 * a.clamp(0.7, 1.0);
    }
  }

  void _paintEndCard(Canvas canvas, Size size, double t) {
    _drawCenteredText(
      canvas,
      size,
      'RIDERLAB',
      fontSize: 42,
      color: AppTheme.mist,
      dy: -160,
      letterSpacing: 6,
      weight: FontWeight.w800,
    );
    _drawCenteredText(
      canvas,
      size,
      copy.endQuestion,
      fontSize: 34,
      color: AppTheme.signal,
      dy: -40,
      weight: FontWeight.w700,
    );
    _drawCenteredText(
      canvas,
      size,
      copy.cta.toUpperCase(),
      fontSize: 18,
      color: AppTheme.line,
      dy: 80,
      letterSpacing: 3,
    );
    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.72),
      18 + 6 * pulse,
      Paint()
        ..color = AppTheme.line.withValues(alpha: 0.25 + 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _paintWatermark(Canvas canvas, Size size) {
    _drawText(
      canvas,
      'RIDERLAB',
      Offset(24, 28),
      fontSize: 14,
      color: const Color(0x88F1F5F8),
      letterSpacing: 2.4,
      weight: FontWeight.w700,
    );
  }

  void _drawCoverPhoto(Canvas canvas, Size size, ui.Image image, {double zoom = 1}) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final scale = math.max(size.width / iw, size.height / ih) * zoom;
    final dw = iw * scale;
    final dh = ih * scale;
    final dx = (size.width - dw) / 2;
    final dy = (size.height - dh) / 2;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH(dx, dy, dw, dh),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _drawHudChip(Canvas canvas, Size size, {required double top, required String text}) {
    final tp = _layout(
      text,
      fontSize: 22,
      color: AppTheme.mist,
      weight: FontWeight.w700,
    );
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, top),
        width: tp.width + 36,
        height: 44,
      ),
      const Radius.circular(22),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xCC1A1E24));
    tp.paint(canvas, Offset((size.width - tp.width) / 2, top - tp.height / 2));
  }

  void _drawCenteredText(
    Canvas canvas,
    Size size,
    String text, {
    required double fontSize,
    required Color color,
    double dy = 0,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w700,
  }) {
    final tp = _layout(
      text,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      weight: weight,
    );
    tp.paint(
      canvas,
      Offset((size.width - tp.width) / 2, size.height / 2 + dy - tp.height / 2),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = _layout(
      text,
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      weight: weight,
    );
    tp.paint(canvas, offset);
  }

  TextPainter _layout(
    String text, {
    required double fontSize,
    required Color color,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w700,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout(maxWidth: 1000);
    return tp;
  }
}

class _MapProject {
  _MapProject(this._minX, this._maxX, this._minY, this._maxY, this._rect);

  final double _minX;
  final double _maxX;
  final double _minY;
  final double _maxY;
  final Rect _rect;

  factory _MapProject.fit(
    List<ReelTrailPoint> trail,
    Size size, {
    double padding = 48,
  }) {
    var minLat = trail.first.lat;
    var maxLat = trail.first.lat;
    var minLng = trail.first.lng;
    var maxLng = trail.first.lng;
    for (final p in trail) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    if ((maxLng - minLng).abs() < 0.0008) {
      minLng -= 0.004;
      maxLng += 0.004;
    }
    if ((maxLat - minLat).abs() < 0.0008) {
      minLat -= 0.004;
      maxLat += 0.004;
    }
    final rect = Rect.fromLTWH(
      padding,
      padding + 40,
      size.width - padding * 2,
      size.height - padding * 2 - 80,
    );
    return _MapProject(minLng, maxLng, minLat, maxLat, rect);
  }

  Offset offset(ReelTrailPoint p) => latLng(p.lat, p.lng);

  Offset latLng(double lat, double lng) {
    final dx = _maxX == _minX ? 0.5 : (lng - _minX) / (_maxX - _minX);
    final dy = _maxY == _minY ? 0.5 : (lat - _minY) / (_maxY - _minY);
    return Offset(
      _rect.left + dx * _rect.width,
      _rect.bottom - dy * _rect.height,
    );
  }
}
