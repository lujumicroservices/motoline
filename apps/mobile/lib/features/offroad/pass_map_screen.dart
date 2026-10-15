import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_model.dart';
import 'pass_channels.dart';
import 'session_model.dart';
import 'track_3d_screen.dart';
import 'widgets/pass_charts.dart';
import 'widgets/trace_heat_layer.dart';

/// Full-screen map of one pass: line coloured by channel, braking zones,
/// peaks, the session's fastest pass as a ghost, and a scrub / replay HUD.
class PassMapScreen extends StatefulWidget {
  const PassMapScreen({
    super.key,
    required this.session,
    required this.pass,
    required this.passIndex,
    this.circuit,
    this.initialChannel = TraceChannel.speed,
    this.initialIndex = 0,
  });

  final TrainingSession session;
  final TrainingPass pass;
  final int passIndex;
  final Circuit? circuit;
  final TraceChannel initialChannel;

  /// Trace row the cursor starts on (e.g. a peak picked in the pass detail).
  final int initialIndex;

  @override
  State<PassMapScreen> createState() => _PassMapScreenState();
}

enum _Base { satellite, none }

class _PassMapScreenState extends State<PassMapScreen>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final _cursor = ValueNotifier<int>(
    widget.initialIndex.clamp(0, widget.pass.trace!.length - 1),
  );
  late TraceChannel _channel = widget.initialChannel;
  var _base = _Base.satellite;
  var _showBrakes = true;
  var _showPeaks = true;
  var _showGhost = false;
  var _chartOpen = true;
  String? _info;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _playT = 0;
  int _speed = 4;

  PassTrace get _trace => widget.pass.trace!;
  late final List<(int, int)> _brakes = passBrakeRanges(widget.pass);
  late final TrainingPass? _ghostPass = _fastestOther();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cursor.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  TrainingPass? _fastestOther() {
    TrainingPass? best;
    for (final p in widget.session.passes) {
      if (p.id == widget.pass.id || p.trace == null) continue;
      if (best == null || p.durationS < best.durationS) best = p;
    }
    final me = widget.pass;
    // Only worth drawing when the reference is actually faster.
    if (best == null || best.durationS >= me.durationS) return null;
    return best;
  }

  void _tick(Duration now) {
    final dt = _lastTick == Duration.zero ? 0.0 : (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    _playT += dt * _speed;
    final t = _trace.t;
    if (_playT >= t.last) {
      _cursor.value = t.length - 1;
      _stop();
      return;
    }
    var i = _cursor.value;
    if (i >= t.length || t[i] > _playT) i = 0;
    while (i < t.length - 1 && t[i + 1] <= _playT) {
      i++;
    }
    _cursor.value = i;
  }

  void _play() {
    if (_cursor.value >= _trace.length - 1) _cursor.value = 0;
    _playT = _trace.t[_cursor.value];
    _lastTick = Duration.zero;
    _ticker.start();
    setState(() => _info = null);
  }

  void _stop() {
    if (_ticker.isActive) _ticker.stop();
    if (mounted) setState(() {});
  }

  void _seek(int i, {String? info}) {
    if (_ticker.isActive) _ticker.stop();
    _cursor.value = i.clamp(0, _trace.length - 1);
    setState(() => _info = info);
  }

  void _onMapTap(TapPosition pos, LatLng _) {
    final cam = _map.camera;
    final tap = pos.relative;
    if (tap == null) return;
    var best = -1;
    var bestD = 36.0 * 36.0;
    for (var i = 0; i < _trace.length; i += 1) {
      final d = (cam.latLngToScreenOffset(_trace.points[i]) - tap).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) _seek(best);
  }

  String _sectorName(int i) {
    final c = widget.circuit;
    if (c != null && i < c.sectors.length) return c.sectors[i].name;
    return 'S${i + 1}';
  }

  String _eventTitle(AppLocalizations l10n, String kind) => switch (kind) {
    'vmax' => l10n.statTopSpeed,
    'lean_r' => l10n.eventLeanRight,
    'lean_l' => l10n.eventLeanLeft,
    'brake' => l10n.eventHardestBrake,
    'accel' => l10n.eventHardestAccel,
    _ => l10n.eventPeakLatG,
  };

  String _eventValue(PassEvent e) => switch (e.kind) {
    'vmax' => '${e.value.toStringAsFixed(1)} km/h',
    'lean_r' || 'lean_l' => '${e.value.toStringAsFixed(1)}°',
    'accel' => '+${e.value.toStringAsFixed(2)} g',
    'brake' => '−${e.value.toStringAsFixed(2)} g',
    _ => '${e.value.toStringAsFixed(2)} g',
  };

  (IconData, Color) _eventStyle(String kind) => switch (kind) {
    'vmax' => (Icons.bolt_rounded, const Color(0xFFF4D35E)),
    'lean_r' => (Icons.turn_right_rounded, OffroadTheme.sector(3)),
    'lean_l' => (Icons.turn_left_rounded, OffroadTheme.sector(1)),
    'brake' => (Icons.do_not_disturb_on_rounded, OffroadTheme.sector(0)),
    'accel' => (Icons.keyboard_double_arrow_up_rounded, OffroadTheme.sector(2)),
    _ => (Icons.u_turn_left_rounded, Colors.white),
  };

  List<Marker> _markers(AppLocalizations l10n) {
    final out = <Marker>[];
    if (_showBrakes) {
      for (var k = 0; k < _brakes.length; k++) {
        final (a, _) = _brakes[k];
        final b = k < widget.pass.brakes.length ? widget.pass.brakes[k] : null;
        out.add(Marker(
          point: _trace.points[a],
          width: 30,
          height: 30,
          child: GestureDetector(
            onTap: () => _seek(
              a,
              info: b == null
                  ? l10n.brakeZone(k + 1)
                  : '${l10n.brakeZone(k + 1)} · ${b.sector} · '
                      '${b.vIn.toStringAsFixed(0)}→${b.vOut.toStringAsFixed(0)} km/h · '
                      '${b.peakG.toStringAsFixed(2)} g · ${b.durationS.toStringAsFixed(1)} s · '
                      '${b.lapM.toStringAsFixed(0)} m',
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: OffroadTheme.sector(0),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
              ),
              child: Text('${k + 1}', style: OffroadTheme.hud(15)),
            ),
          ),
        ));
      }
    }
    if (_showPeaks) {
      for (final e in widget.pass.events) {
        final (icon, color) = _eventStyle(e.kind);
        out.add(Marker(
          point: e.point,
          width: 128,
          height: 30,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _seek(
              e.index,
              info: '${_eventTitle(l10n, e.kind)} ${_eventValue(e)} · '
                  '${e.kmh.toStringAsFixed(0)} km/h · ${e.lapM.toStringAsFixed(0)} m',
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.fromLTRB(4, 2, 7, 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: Colors.black),
                    const SizedBox(width: 2),
                    Text(_eventValue(e), style: OffroadTheme.hud(14, color: Colors.black)),
                  ],
                ),
              ),
            ),
          ),
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.circuit;
    final tr = _trace;
    final range = _channel.range(tr);
    final bounds = LatLngBounds.fromPoints([...tr.points, ...?c?.outer]);
    return Scaffold(
      backgroundColor: OffroadTheme.field,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.fromLTRB(20, 150, 20, 290),
              ),
              maxZoom: 21,
              backgroundColor: OffroadTheme.field,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _onMapTap,
            ),
            children: [
              if (_base == _Base.satellite)
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                  maxNativeZoom: 19,
                  userAgentPackageName: 'com.rawthrottle.riderlab',
                ),
              if (c != null)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: c.outer,
                      holePointsList: [c.inner],
                      color: OffroadTheme.track.withValues(
                        alpha: _base == _Base.none ? 0.28 : 0.16,
                      ),
                      borderColor: Colors.black.withValues(alpha: 0.6),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              if (c != null)
                PolylineLayer(
                  polylines: [
                    for (final g in c.gates)
                      Polyline(
                        points: [g.a, g.b],
                        color: g.kind == 0
                            ? Colors.white
                            : OffroadTheme.sector(c.sectorIndexAt(g.s)),
                        strokeWidth: 3,
                        borderColor: OffroadTheme.outline,
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
              TraceHeatLayer(
                trace: tr,
                channel: _channel,
                brakes: _showBrakes ? _brakes : const [],
                ghost: _showGhost ? _ghostPass?.trace : null,
              ),
              MarkerLayer(markers: _markers(l10n)),
              ValueListenableBuilder<int>(
                valueListenable: _cursor,
                builder: (context, i, _) {
                  final j = math.min(i + 1, tr.length - 1);
                  final heading = j == i
                      ? 0.0
                      : const Distance().bearing(tr.points[i], tr.points[j]) * math.pi / 180;
                  return MarkerLayer(
                    markers: [
                      Marker(
                        point: tr.points[i],
                        width: 34,
                        height: 34,
                        child: Transform.rotate(
                          angle: heading,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black87, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.offroadPass} ${widget.passIndex + 1} · ${widget.pass.id}',
                                style: GoogleFonts.exo2(fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${widget.session.circuitName} · ${widget.pass.startLocal}',
                                style: OffroadTheme.label(color: OffroadTheme.textFaint)
                                    .copyWith(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: l10n.circuitLayerSatellite,
                        onPressed: () => setState(() {
                          _base = _base == _Base.satellite ? _Base.none : _Base.satellite;
                        }),
                        icon: Icon(
                          _base == _Base.satellite
                              ? Icons.satellite_alt_rounded
                              : Icons.layers_clear_rounded,
                        ),
                      ),
                      if (c != null)
                        IconButton.filled(
                          tooltip: l10n.pass3dOpen,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Track3DScreen(
                                circuit: c,
                                pass: widget.pass,
                                title: '${l10n.offroadPass} ${widget.passIndex + 1} · ${widget.pass.id}',
                                initialChannel: _channel == TraceChannel.elevation ||
                                        _channel == TraceChannel.offLine
                                    ? TraceChannel.speed
                                    : _channel,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.view_in_ar_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final ch in TraceChannel.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _Chip(
                              icon: ch.icon,
                              label: ch.label(l10n),
                              selected: _channel == ch,
                              onTap: () => setState(() => _channel = ch),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChannelLegend(channel: _channel, range: range, width: 150),
                            if (_channel.estimated)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  l10n.channelEstimatedShort,
                                  style: const TextStyle(fontSize: 10, color: OffroadTheme.textFaint),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _Toggle(
                            label: l10n.passMapBrakes(_brakes.length),
                            color: OffroadTheme.sector(0),
                            on: _showBrakes,
                            onTap: () => setState(() => _showBrakes = !_showBrakes),
                          ),
                          const SizedBox(height: 6),
                          _Toggle(
                            label: l10n.passMapPeaks,
                            color: const Color(0xFFF4D35E),
                            on: _showPeaks,
                            onTap: () => setState(() => _showPeaks = !_showPeaks),
                          ),
                          if (_ghostPass != null) ...[
                            const SizedBox(height: 6),
                            _Toggle(
                              label: l10n.passMapGhost(_ghostPass.id),
                              color: Colors.white,
                              on: _showGhost,
                              onTap: () => setState(() => _showGhost = !_showGhost),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: _BottomPanel(
                trace: tr,
                channel: _channel,
                brakes: _showBrakes ? _brakes : const [],
                cursor: _cursor,
                playing: _ticker.isActive,
                speed: _speed,
                info: _info,
                chartOpen: _chartOpen,
                sectorName: _sectorName,
                onPlay: () => _ticker.isActive ? _stop() : _play(),
                onSpeed: () => setState(() => _speed = switch (_speed) { 1 => 4, 4 => 8, _ => 1 }),
                onSeek: _seek,
                onToggleChart: () => setState(() => _chartOpen = !_chartOpen),
                onCloseInfo: () => setState(() => _info = null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.trace,
    required this.channel,
    required this.brakes,
    required this.cursor,
    required this.playing,
    required this.speed,
    required this.info,
    required this.chartOpen,
    required this.sectorName,
    required this.onPlay,
    required this.onSpeed,
    required this.onSeek,
    required this.onToggleChart,
    required this.onCloseInfo,
  });

  final PassTrace trace;
  final TraceChannel channel;
  final List<(int, int)> brakes;
  final ValueNotifier<int> cursor;
  final bool playing;
  final int speed;
  final String? info;
  final bool chartOpen;
  final String Function(int) sectorName;
  final VoidCallback onPlay;
  final VoidCallback onSpeed;
  final void Function(int, {String? info}) onSeek;
  final VoidCallback onToggleChart;
  final VoidCallback onCloseInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: OffroadTheme.panel.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(OffroadTheme.radiusLg),
        border: Border.all(color: OffroadTheme.panelBorder),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: cursor,
        builder: (context, i, _) {
          final t = trace;
          final braking = t.braking[i] == 1;
          final lean = t.lean[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (info != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                  decoration: BoxDecoration(
                    color: OffroadTheme.track.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
                    border: Border.all(color: OffroadTheme.track.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          info!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      InkWell(
                        onTap: onCloseInfo,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Hud(value: t.kmh[i].toStringAsFixed(0), unit: 'km/h', label: l10n.channelSpeed, big: true),
                  _Hud(
                    value: '${lean.abs().toStringAsFixed(0)}°',
                    unit: lean.abs() < 1 ? '' : (lean > 0 ? l10n.hudRight : l10n.hudLeft),
                    label: l10n.hudLean,
                  ),
                  _Hud(
                    value: TraceChannel.longG.format(t.longG[i]),
                    unit: 'g',
                    label: l10n.hudLongG,
                    color: braking
                        ? OffroadTheme.sector(0)
                        : (t.longG[i] > 0.05 ? OffroadTheme.sector(2) : null),
                  ),
                  _Hud(value: t.latG[i].abs().toStringAsFixed(2), unit: 'g', label: l10n.hudLatG),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: OffroadTheme.sector(t.sector[i]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(sectorName(t.sector[i]), style: OffroadTheme.hud(15, color: Colors.black)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${t.lapM[i].toStringAsFixed(0)} m',
                        style: OffroadTheme.hud(14, color: OffroadTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              if (braking)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.hudBraking,
                    style: OffroadTheme.label(color: OffroadTheme.sector(0)),
                  ),
                ),
              if (chartOpen) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 92,
                  child: ChannelChart(
                    trace: t,
                    channel: channel,
                    brakes: brakes,
                    cursor: i,
                    onScrub: onSeek,
                    compact: true,
                  ),
                ),
              ],
              Row(
                children: [
                  IconButton(
                    onPressed: onPlay,
                    icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
                    iconSize: 34,
                    color: OffroadTheme.track,
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    onPressed: onSpeed,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(40, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: Text('$speed×', style: OffroadTheme.hud(16, color: OffroadTheme.track)),
                  ),
                  Expanded(
                    child: Slider(
                      value: i.toDouble(),
                      min: 0,
                      max: (t.length - 1).toDouble(),
                      onChanged: (v) => onSeek(v.round()),
                    ),
                  ),
                  Text(_clock(t.t[i]), style: OffroadTheme.hud(15, color: OffroadTheme.textMuted)),
                  IconButton(
                    onPressed: onToggleChart,
                    icon: Icon(chartOpen ? Icons.expand_more_rounded : Icons.show_chart_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _clock(double s) {
    final m = s ~/ 60;
    final r = s - m * 60;
    return '$m:${r.toStringAsFixed(1).padLeft(4, '0')}';
  }
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.value,
    required this.unit,
    required this.label,
    this.big = false,
    this.color,
  });

  final String value;
  final String unit;
  final String label;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: big ? 5 : 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: OffroadTheme.hud(big ? 34 : 24, color: color ?? OffroadTheme.text),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: OffroadTheme.hud(big ? 14 : 12, color: OffroadTheme.textMuted),
                  ),
              ],
            ),
            maxLines: 1,
          ),
          Text(
            label,
            style: OffroadTheme.label(color: OffroadTheme.textFaint).copyWith(fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : OffroadTheme.text;
    return Material(
      color: selected ? OffroadTheme.track : Colors.black.withValues(alpha: 0.65),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? OffroadTheme.track : OffroadTheme.panelBorder),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.color,
    required this.on,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: on ? color : OffroadTheme.textFaint,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: on ? OffroadTheme.text : OffroadTheme.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
