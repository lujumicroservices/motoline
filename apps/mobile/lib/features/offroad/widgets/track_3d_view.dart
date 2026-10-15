import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../theme/offroad_theme.dart';
import '../circuit_model.dart';
import '../pass_channels.dart';
import '../session_model.dart';

/// Pin drawn above the track in the 3D view (peaks of a pass).
class Track3DPin {
  const Track3DPin({required this.point, required this.lapM, required this.label, required this.color});
  final LatLng point;
  final double lapM;
  final String label;
  final Color color;
}

/// Corridor ribbon at the mapped elevation, walls down to a ground grid, and an
/// optional pass line on top. Drag to orbit, pinch to zoom.
class Track3DView extends StatefulWidget {
  const Track3DView({
    super.key,
    required this.circuit,
    this.trace,
    this.channel = TraceChannel.speed,
    this.exaggeration = 3,
    this.autoRotate = false,
    this.pins = const [],
    this.onUserInteraction,
  });

  final Circuit circuit;
  final PassTrace? trace;
  final TraceChannel channel;

  /// Vertical scale factor; the real relief of a motocross track is a few metres.
  final double exaggeration;
  final bool autoRotate;
  final List<Track3DPin> pins;
  final VoidCallback? onUserInteraction;

  @override
  State<Track3DView> createState() => _Track3DViewState();
}

class _Track3DViewState extends State<Track3DView>
    with SingleTickerProviderStateMixin {
  late _TrackGeometry _geo;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  late double _yaw;
  double _pitch = 0.72;
  late double _dist;
  double _startDist = 0;

  @override
  void initState() {
    super.initState();
    _geo = _TrackGeometry(widget.circuit);
    _yaw = _geo.homeYaw;
    _dist = _geo.extent * 0.98;
    _ticker = createTicker(_tick);
    if (widget.autoRotate) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant Track3DView old) {
    super.didUpdateWidget(old);
    if (old.circuit != widget.circuit) _geo = _TrackGeometry(widget.circuit);
    if (widget.autoRotate && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!widget.autoRotate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.0 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    setState(() => _yaw += dt * 0.22);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _yaw = _geo.homeYaw;
    _pitch = 0.72;
    _dist = _geo.extent * 0.98;
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _reset,
      onScaleStart: (_) {
        _startDist = _dist;
        widget.onUserInteraction?.call();
      },
      onScaleUpdate: (d) => setState(() {
        if (d.pointerCount > 1) {
          _dist = (_startDist / d.scale).clamp(_geo.extent * 0.25, _geo.extent * 4);
        } else {
          _yaw -= d.focalPointDelta.dx * 0.008;
          _pitch = (_pitch + d.focalPointDelta.dy * 0.006).clamp(0.12, 1.5);
        }
      }),
      child: CustomPaint(
        size: Size.infinite,
        painter: _Track3DPainter(
          geo: _geo,
          trace: widget.trace,
          channel: widget.channel,
          range: widget.trace == null ? null : widget.channel.range(widget.trace!),
          ex: widget.exaggeration,
          yaw: _yaw,
          pitch: _pitch,
          dist: _dist,
          pins: widget.pins,
        ),
      ),
    );
  }
}

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;
}

/// Local metric frame around the circuit anchor plus the resampled corridor.
class _TrackGeometry {
  _TrackGeometry(this.c)
      : lat0 = c.anchor.latitude,
        lng0 = c.anchor.longitude,
        kx = math.cos(c.anchor.latitude * math.pi / 180) * 111320 {
    final outer = [for (final p in c.outer) xy(p)];
    final inner = [for (final p in c.inner) xy(p)];
    final n = math.max(60, (c.lengthM / 2.5).round());
    for (var k = 0; k < n; k++) {
      final s = c.lengthM * k / n;
      final m = _centerAt(s);
      slices.add((s: s, outer: _nearest(outer, m), inner: _nearest(inner, m)));
    }
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in [...outer, ...inner]) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    extent = math.max(bounds.width, bounds.height);
    elevMin = c.elevMin;

    final m = bounds.center;
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in outer) {
      final d = p - m;
      sxx += d.dx * d.dx;
      syy += d.dy * d.dy;
      sxy += d.dx * d.dy;
    }
    // Principal axis of the layout; the camera starts looking along it so a
    // long, narrow circuit fits a portrait screen.
    final axis = 0.5 * math.atan2(2 * sxy, sxx - syy);
    homeYaw = math.pi / 2 - axis;
  }

  late final double homeYaw;

  final Circuit c;
  final double lat0, lng0, kx;
  static const ky = 110574.0;
  final slices = <({double s, Offset outer, Offset inner})>[];
  late final Rect bounds;
  late final double extent;
  late final double elevMin;

  Offset xy(LatLng p) => Offset((p.longitude - lng0) * kx, (p.latitude - lat0) * ky);

  double elevAt(double s) {
    final e = c.elevation;
    if (e.isEmpty) return 0;
    final x = (s % c.lengthM) / c.elevStepM;
    final i = x.floor().clamp(0, e.length - 1);
    final j = math.min(i + 1, e.length - 1);
    return e[i] + (e[j] - e[i]) * (x - i);
  }

  Offset _centerAt(double s) {
    final cum = c.centerCum;
    var i = 0;
    while (i < cum.length - 1 && cum[i + 1] < s) {
      i++;
    }
    final a = xy(c.center[i]);
    final b = xy(c.center[(i + 1) % c.center.length]);
    final segEnd = i + 1 < cum.length ? cum[i + 1] : c.lengthM;
    final f = segEnd > cum[i] ? ((s - cum[i]) / (segEnd - cum[i])).clamp(0.0, 1.0) : 0.0;
    return Offset.lerp(a, b, f)!;
  }

  static Offset _nearest(List<Offset> ring, Offset p) {
    var best = ring.first;
    var bestD = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      final q = a + ab * t;
      final d = (q - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = q;
      }
    }
    return best;
  }
}

class _Item {
  _Item(this.depth, this.path, this.paint);
  final double depth;
  final Path path;
  final Paint paint;
}

class _Track3DPainter extends CustomPainter {
  _Track3DPainter({
    required this.geo,
    required this.trace,
    required this.channel,
    required this.range,
    required this.ex,
    required this.yaw,
    required this.pitch,
    required this.dist,
    required this.pins,
  });

  final _TrackGeometry geo;
  final PassTrace? trace;
  final TraceChannel channel;
  final (double, double)? range;
  final double ex;
  final double yaw, pitch, dist;
  final List<Track3DPin> pins;

  static const _ground = -1.5;
  static const _light = _V3(-0.42, 0.48, 0.77);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0F14), Color(0xFF050505)],
        ).createShader(Offset.zero & size),
    );

    final center = geo.bounds.center;
    final zMid = (geo.c.elevDrop * ex) / 2;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final focal = size.shortestSide * 1.15;
    final origin = Offset(size.width / 2, size.height * 0.46);

    // Returns screen position and depth (larger = farther).
    (Offset, double) project(double x, double y, double z) {
      final dx = x - center.dx, dy = y - center.dy, dz = z - zMid;
      final xr = dx * cy - dy * sy;
      final yr = dx * sy + dy * cy;
      final up = yr * sp + dz * cp;
      final depth = yr * cp - dz * sp;
      final f = focal / math.max(1.0, dist + depth);
      return (origin + Offset(xr * f, -up * f), depth);
    }

    double zAt(double s) => (geo.elevAt(s) - geo.elevMin) * ex;

    _drawGrid(canvas, project);

    final items = <_Item>[];
    final n = geo.slices.length;
    final top = <(Offset, double)>[];
    final topIn = <(Offset, double)>[];
    final baseOut = <(Offset, double)>[];
    final baseIn = <(Offset, double)>[];
    final zs = <double>[];
    for (final sl in geo.slices) {
      final z = zAt(sl.s);
      zs.add(z);
      top.add(project(sl.outer.dx, sl.outer.dy, z));
      topIn.add(project(sl.inner.dx, sl.inner.dy, z));
      baseOut.add(project(sl.outer.dx, sl.outer.dy, _ground));
      baseIn.add(project(sl.inner.dx, sl.inner.dy, _ground));
    }

    final hasPass = trace != null;
    for (var k = 0; k < n; k++) {
      final j = (k + 1) % n;
      final a = geo.slices[k], b = geo.slices[j];
      final shade = _shade(a.outer, b.outer, a.inner, zs[k], zs[j]);
      final Color base;
      if (hasPass) {
        // Neutral dirt so the channel colours of the line stay readable.
        base = const Color(0xFF6B5D4F);
      } else {
        base = TraceChannel.elevation.color(
          geo.elevAt(a.s),
          (geo.c.elevMin, math.max(geo.c.elevMax, geo.c.elevMin + 1)),
        );
      }
      final roof = Path()
        ..moveTo(top[k].$1.dx, top[k].$1.dy)
        ..lineTo(top[j].$1.dx, top[j].$1.dy)
        ..lineTo(topIn[j].$1.dx, topIn[j].$1.dy)
        ..lineTo(topIn[k].$1.dx, topIn[k].$1.dy)
        ..close();
      items.add(_Item(
        (top[k].$2 + top[j].$2 + topIn[k].$2 + topIn[j].$2) / 4,
        roof,
        Paint()..color = _darken(base, shade),
      ));

      for (final (t0, t1, b0, b1, p0, p1) in [
        (top[k], top[j], baseOut[k], baseOut[j], a.outer, b.outer),
        (topIn[k], topIn[j], baseIn[k], baseIn[j], a.inner, b.inner),
      ]) {
        final wall = Path()
          ..moveTo(t0.$1.dx, t0.$1.dy)
          ..lineTo(t1.$1.dx, t1.$1.dy)
          ..lineTo(b1.$1.dx, b1.$1.dy)
          ..lineTo(b0.$1.dx, b0.$1.dy)
          ..close();
        final e = p1 - p0;
        final len = math.max(1e-6, e.distance);
        final wn = _V3(e.dy / len, -e.dx / len, 0);
        final lit = (wn.x * _light.x + wn.y * _light.y).abs();
        items.add(_Item(
          (t0.$2 + t1.$2 + b0.$2 + b1.$2) / 4 + 0.01,
          wall,
          Paint()..color = Color.lerp(const Color(0xFF1A1A1A), const Color(0xFF5A4630), lit)!,
        ));
      }
    }

    final tr = trace;
    final r = range;
    if (tr != null && r != null) {
      final pts = <(Offset, double)>[];
      for (var i = 0; i < tr.length; i++) {
        final p = geo.xy(tr.points[i]);
        pts.add(project(p.dx, p.dy, zAt(tr.lapM[i]) + 0.4));
      }
      final w = (focal / dist * 4.5).clamp(2.2, 7.0);
      for (var i = 1; i < pts.length; i++) {
        final seg = Path()
          ..moveTo(pts[i - 1].$1.dx, pts[i - 1].$1.dy)
          ..lineTo(pts[i].$1.dx, pts[i].$1.dy);
        items.add(_Item(
          (pts[i - 1].$2 + pts[i].$2) / 2 - 0.5,
          seg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = w
            ..color = channel.color(channel.value(tr, i), r),
        ));
      }
    }

    items.sort((a, b) => b.depth.compareTo(a.depth));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withValues(alpha: 0.35);
    for (final it in items) {
      canvas.drawPath(it.path, it.paint);
      if (it.paint.style == PaintingStyle.fill) canvas.drawPath(it.path, edge);
    }

    _drawGates(canvas, project, zAt);
    _drawPins(canvas, project, zAt);
  }

  double _shade(Offset o0, Offset o1, Offset i0, double z0, double z1) {
    final u = _V3(o1.dx - o0.dx, o1.dy - o0.dy, z1 - z0);
    final v = _V3(i0.dx - o0.dx, i0.dy - o0.dy, 0);
    var nx = u.y * v.z - u.z * v.y;
    var ny = u.z * v.x - u.x * v.z;
    var nz = u.x * v.y - u.y * v.x;
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-9) return 1;
    nx /= len;
    ny /= len;
    nz /= len;
    if (nz < 0) {
      nx = -nx;
      ny = -ny;
      nz = -nz;
    }
    final d = nx * _light.x + ny * _light.y + nz * _light.z;
    return (0.55 + 0.45 * d).clamp(0.4, 1.0);
  }

  Color _darken(Color c, double k) => Color.fromARGB(
    255,
    (c.r * 255 * k).round().clamp(0, 255),
    (c.g * 255 * k).round().clamp(0, 255),
    (c.b * 255 * k).round().clamp(0, 255),
  );

  void _drawGrid(Canvas canvas, (Offset, double) Function(double, double, double) project) {
    final b = geo.bounds.inflate(geo.extent * 0.12);
    const step = 20.0;
    final paint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF1E2A33);
    for (var x = (b.left / step).floor() * step; x <= b.right; x += step) {
      canvas.drawLine(project(x, b.top, _ground).$1, project(x, b.bottom, _ground).$1, paint);
    }
    for (var y = (b.top / step).floor() * step; y <= b.bottom; y += step) {
      canvas.drawLine(project(b.left, y, _ground).$1, project(b.right, y, _ground).$1, paint);
    }
  }

  void _drawGates(
    Canvas canvas,
    (Offset, double) Function(double, double, double) project,
    double Function(double) zAt,
  ) {
    for (final g in geo.c.gates) {
      final a = geo.xy(g.a), b = geo.xy(g.b);
      final z = zAt(g.s);
      final color = g.kind == 0 ? Colors.white : OffroadTheme.sector(geo.c.sectorIndexAt(g.s));
      final pa = project(a.dx, a.dy, z + 0.3).$1;
      final pb = project(b.dx, b.dy, z + 0.3).$1;
      final post = Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.black;
      canvas.drawLine(pa, pb, post);
      canvas.drawLine(pa, pb, Paint()
        ..strokeWidth = 1.6
        ..color = color);
      for (final p in [a, b]) {
        final foot = project(p.dx, p.dy, z).$1;
        final head = project(p.dx, p.dy, z + 4 * math.max(1, ex / 2)).$1;
        canvas.drawLine(foot, head, post);
        canvas.drawLine(foot, head, Paint()
          ..strokeWidth = 1.6
          ..color = color);
      }
      if (g.kind == 0) {
        final m = Offset.lerp(a, b, 0.5)!;
        final flag = project(m.dx, m.dy, z + 4 * math.max(1, ex / 2)).$1;
        canvas.drawCircle(flag, 9, Paint()..color = Colors.black);
        const glyph = Icons.sports_score_rounded;
        final icon = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(glyph.codePoint),
            style: TextStyle(
              fontFamily: glyph.fontFamily,
              package: glyph.fontPackage,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        icon.paint(canvas, flag - Offset(icon.width / 2, icon.height / 2));
      }
    }
  }

  void _drawPins(
    Canvas canvas,
    (Offset, double) Function(double, double, double) project,
    double Function(double) zAt,
  ) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final pin in pins) {
      final p = geo.xy(pin.point);
      final z = zAt(pin.lapM);
      final foot = project(p.dx, p.dy, z + 0.4).$1;
      final head = project(p.dx, p.dy, z + 7 * math.max(1, ex / 2)).$1;
      canvas.drawLine(foot, head, Paint()
        ..strokeWidth = 1.5
        ..color = pin.color);
      tp
        ..text = TextSpan(
          text: pin.label,
          style: OffroadTheme.hud(13, color: Colors.black),
        )
        ..layout();
      final box = Rect.fromCenter(
        center: head - Offset(0, tp.height / 2 + 3),
        width: tp.width + 10,
        height: tp.height + 6,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(5)), Paint()..color = pin.color);
      tp.paint(canvas, box.topLeft + const Offset(5, 3));
      canvas.drawCircle(foot, 3, Paint()..color = pin.color);
    }
  }

  @override
  bool shouldRepaint(covariant _Track3DPainter old) => true;
}
