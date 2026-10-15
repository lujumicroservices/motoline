import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_model.dart';
import 'pass_channels.dart';
import 'session_model.dart';
import 'widgets/trace_heat_layer.dart';
import 'widgets/track_3d_view.dart';

/// Circuit on its relief in 3D; with a [pass], its line coloured by channel.
class Track3DScreen extends StatefulWidget {
  const Track3DScreen({
    super.key,
    required this.circuit,
    this.pass,
    this.title,
    this.initialChannel = TraceChannel.speed,
  });

  final Circuit circuit;
  final TrainingPass? pass;
  final String? title;
  final TraceChannel initialChannel;

  @override
  State<Track3DScreen> createState() => _Track3DScreenState();
}

class _Track3DScreenState extends State<Track3DScreen> {
  late TraceChannel _channel = widget.initialChannel;
  double _ex = 3;
  bool _spin = true;

  static const _channels = [
    TraceChannel.speed,
    TraceChannel.longG,
    TraceChannel.lean,
    TraceChannel.latG,
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  List<Track3DPin> _pins() {
    final p = widget.pass;
    if (p == null) return const [];
    final out = <Track3DPin>[];
    final v = p.event('vmax');
    if (v != null) {
      out.add(Track3DPin(
        point: v.point,
        lapM: v.lapM,
        label: '${v.value.toStringAsFixed(0)} km/h',
        color: const Color(0xFFF4D35E),
      ));
    }
    final r = p.event('lean_r'), l = p.event('lean_l');
    final lean = r == null ? l : (l == null || r.value >= l.value ? r : l);
    if (lean != null) {
      out.add(Track3DPin(
        point: lean.point,
        lapM: lean.lapM,
        label: '${lean.value.toStringAsFixed(0)}°',
        color: OffroadTheme.sector(1),
      ));
    }
    final b = p.event('brake');
    if (b != null) {
      out.add(Track3DPin(
        point: b.point,
        lapM: b.lapM,
        label: '${b.value.toStringAsFixed(2)} g',
        color: OffroadTheme.sector(0),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.circuit;
    final trace = widget.pass?.trace;
    return Scaffold(
      backgroundColor: OffroadTheme.field,
      body: Stack(
        children: [
          Positioned.fill(
            child: Track3DView(
              circuit: c,
              trace: trace,
              channel: _channel,
              exaggeration: _ex,
              autoRotate: _spin,
              pins: _pins(),
              onUserInteraction: () {
                if (_spin) setState(() => _spin = false);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title ?? l10n.track3dTitle,
                              style: GoogleFonts.exo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              c.name,
                              style: OffroadTheme.label(color: OffroadTheme.textFaint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (trace != null) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final ch in _channels)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: Icon(
                                  ch.icon,
                                  size: 16,
                                  color: _channel == ch ? Colors.black : OffroadTheme.text,
                                ),
                                label: Text(ch.label(l10n)),
                                selected: _channel == ch,
                                onSelected: (_) => setState(() => _channel = ch),
                                selectedColor: OffroadTheme.track,
                                backgroundColor: OffroadTheme.panel.withValues(alpha: 0.9),
                                labelStyle: TextStyle(
                                  color: _channel == ch ? Colors.black : OffroadTheme.text,
                                  fontWeight: FontWeight.w700,
                                ),
                                showCheckmark: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
                      ),
                      child: ChannelLegend(channel: _channel, range: _channel.range(trace)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: OffroadTheme.panel.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(OffroadTheme.radiusMd),
                  border: Border.all(color: OffroadTheme.panelBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Stat(c.elevDrop.toStringAsFixed(1), 'm', l10n.circuitStatDrop),
                        _Stat(c.elevMin.toStringAsFixed(0), 'm', l10n.circuitStatElevMin),
                        _Stat(c.elevMax.toStringAsFixed(0), 'm', l10n.circuitStatElevMax),
                        FilterChip(
                          avatar: Icon(
                            Icons.threesixty_rounded,
                            size: 16,
                            color: _spin ? Colors.black : OffroadTheme.text,
                          ),
                          label: Text(l10n.track3dAutoRotate),
                          selected: _spin,
                          onSelected: (v) => setState(() => _spin = v),
                          selectedColor: OffroadTheme.track,
                          labelStyle: TextStyle(
                            color: _spin ? Colors.black : OffroadTheme.text,
                            fontWeight: FontWeight.w700,
                          ),
                          showCheckmark: false,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          l10n.track3dExaggeration(_ex.toStringAsFixed(0)),
                          style: OffroadTheme.label(),
                        ),
                        Expanded(
                          child: Slider(
                            value: _ex,
                            min: 1,
                            max: 8,
                            divisions: 7,
                            onChanged: (v) => setState(() => _ex = v),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      l10n.track3dNote(_ex.toStringAsFixed(0), c.elevSource),
                      style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.track3dHelp,
                      style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.unit, this.label);
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: OffroadTheme.hud(22)),
                TextSpan(
                  text: ' $unit',
                  style: OffroadTheme.hud(12, color: OffroadTheme.textMuted),
                ),
              ],
            ),
          ),
          Text(label, style: OffroadTheme.label(color: OffroadTheme.textFaint).copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
