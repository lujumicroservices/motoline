import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_model.dart';
import 'offroad_home_screen.dart' show CircuitStat;
import 'pass_analysis.dart';
import 'pass_channels.dart';
import 'pass_map_screen.dart';
import 'session_model.dart';
import 'track_3d_screen.dart';
import 'widgets/circuit_silhouette.dart';
import 'widgets/pass_charts.dart';

/// One pass on the circuit: sector deltas vs session best + why faster/slower.
class PassDetailScreen extends ConsumerWidget {
  const PassDetailScreen({
    super.key,
    required this.session,
    required this.pass,
    required this.passIndex,
  });

  final TrainingSession session;
  final TrainingPass pass;
  final int passIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final analysis = PassAnalysis(session, pass);
    final circuits = ref.watch(circuitsProvider).valueOrNull ?? const [];
    Circuit? circuit;
    for (final c in circuits) {
      if (c.id == session.circuitId) {
        circuit = c;
        break;
      }
    }
    final trace = pass.trace;
    final title = '${l10n.offroadPass} ${passIndex + 1} · ${pass.id}';

    void openMap({TraceChannel channel = TraceChannel.speed, int index = 0}) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PassMapScreen(
            session: session,
            pass: pass,
            passIndex: passIndex,
            circuit: circuit,
            initialChannel: channel,
            initialIndex: index,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.offroadPass} ${passIndex + 1} · ${pass.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (circuit != null)
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    color: OffroadTheme.field,
                    padding: const EdgeInsets.all(12),
                    child: CircuitSilhouette(circuit: circuit),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Text(
                      '${circuit.name} · ${pass.startLocal} – ${pass.endLocal}',
                      style: OffroadTheme.label(color: OffroadTheme.textMuted),
                    ),
                  ),
                  if (trace != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: openMap,
                              icon: const Icon(Icons.fullscreen_rounded),
                              label: Text(l10n.passMapOpen),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => Track3DScreen(
                                    circuit: circuit!,
                                    pass: pass,
                                    title: title,
                                  ),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: OffroadTheme.track,
                                side: const BorderSide(color: OffroadTheme.track),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              icon: const Icon(Icons.view_in_ar_rounded),
                              label: Text(l10n.pass3dOpen),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _Headline(analysis: analysis, pass: pass),
          const SizedBox(height: 16),
          Row(
            children: [
              CircuitStat(
                value: (pass.durationS / 60).toStringAsFixed(1),
                unit: 'min',
                label: l10n.offroadDuration,
                size: 26,
              ),
              CircuitStat(
                value: pass.vmaxKmh.toStringAsFixed(0),
                unit: 'km/h',
                label: l10n.statTopSpeed,
                size: 26,
              ),
              CircuitStat(
                value: pass.vavgKmh.toStringAsFixed(0),
                unit: 'km/h',
                label: l10n.offroadAvgSpeed,
                size: 26,
              ),
              CircuitStat(
                value: '${(100 - pass.pctOutside).toStringAsFixed(0)}%',
                label: l10n.offroadInsideTrack,
                size: 26,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircuitStat(
                value: pass.leanMaxL.toStringAsFixed(0),
                unit: '°',
                label: l10n.eventLeanLeftShort,
                size: 26,
              ),
              CircuitStat(
                value: pass.leanMaxR.toStringAsFixed(0),
                unit: '°',
                label: l10n.eventLeanRightShort,
                size: 26,
              ),
              CircuitStat(
                value: pass.brakePeakG.toStringAsFixed(2),
                unit: 'g',
                label: l10n.eventHardestBrakeShort,
                size: 26,
              ),
              CircuitStat(
                value: pass.accelPeakG.toStringAsFixed(2),
                unit: 'g',
                label: l10n.eventHardestAccelShort,
                size: 26,
              ),
            ],
          ),
          if (trace != null) ...[
            if (pass.events.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.passKeyMoments,
                style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.passKeyMomentsHelp,
                style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
              ),
              const SizedBox(height: 8),
              for (final e in pass.events)
                _EventRow(
                  event: e,
                  circuit: circuit,
                  onTap: () => openMap(channel: _channelFor(e.kind), index: e.index),
                ),
            ],
            const SizedBox(height: 20),
            _TelemetryCard(pass: pass, onOpenMap: (ch) => openMap(channel: ch)),
            const SizedBox(height: 16),
            _GgCard(trace: trace),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.offroadSectorsVsBest,
            style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.offroadSectorsVsBestHelp,
            style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final s in analysis.sectors) _SectorRow(delta: s, circuit: circuit),
          const SizedBox(height: 20),
          Text(
            l10n.offroadWhyPace,
            style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final f in analysis.factors) _FactorCard(factor: f),
          if (pass.brakes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.offroadBrakingZones,
              style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final b in pass.brakes) _BrakeRow(brake: b),
          ],
        ],
      ),
    );
  }
}

TraceChannel _channelFor(String kind) => switch (kind) {
  'vmax' => TraceChannel.speed,
  'lean_r' || 'lean_l' => TraceChannel.lean,
  'lat_g' => TraceChannel.latG,
  _ => TraceChannel.longG,
};

String _eventTitle(AppLocalizations l10n, String kind) => switch (kind) {
  'vmax' => l10n.statTopSpeed,
  'lean_r' => l10n.eventLeanRight,
  'lean_l' => l10n.eventLeanLeft,
  'brake' => l10n.eventHardestBrake,
  'accel' => l10n.eventHardestAccel,
  _ => l10n.eventPeakLatG,
};

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.onTap, this.circuit});
  final PassEvent event;
  final Circuit? circuit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = event;
    final (icon, color) = switch (e.kind) {
      'vmax' => (Icons.bolt_rounded, const Color(0xFFF4D35E)),
      'lean_r' => (Icons.turn_right_rounded, OffroadTheme.sector(3)),
      'lean_l' => (Icons.turn_left_rounded, OffroadTheme.sector(1)),
      'brake' => (Icons.do_not_disturb_on_rounded, OffroadTheme.sector(0)),
      'accel' => (Icons.keyboard_double_arrow_up_rounded, OffroadTheme.sector(2)),
      _ => (Icons.u_turn_left_rounded, Colors.white),
    };
    final value = switch (e.kind) {
      'vmax' => '${e.value.toStringAsFixed(1)} km/h',
      'lean_r' || 'lean_l' => '${e.value.toStringAsFixed(1)}°',
      _ => '${e.value.toStringAsFixed(2)} g',
    };
    final c = circuit;
    final sector = c == null ? '' : '${c.sectors[c.sectorIndexAt(e.lapM)].name} · ';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(OffroadTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventTitle(l10n, e.kind),
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      '$sector${e.lapM.toStringAsFixed(0)} m · ${e.kmh.toStringAsFixed(0)} km/h',
                      style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(value, style: OffroadTheme.hud(22, color: color)),
              const SizedBox(width: 4),
              const Icon(Icons.map_rounded, size: 18, color: OffroadTheme.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatefulWidget {
  const _TelemetryCard({required this.pass, required this.onOpenMap});
  final TrainingPass pass;
  final ValueChanged<TraceChannel> onOpenMap;

  @override
  State<_TelemetryCard> createState() => _TelemetryCardState();
}

class _TelemetryCardState extends State<_TelemetryCard> {
  var _channel = TraceChannel.speed;
  int? _cursor;
  late final _brakes = passBrakeRanges(widget.pass);

  static const _channels = [
    TraceChannel.speed,
    TraceChannel.longG,
    TraceChannel.lean,
    TraceChannel.latG,
    TraceChannel.elevation,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = widget.pass.trace!;
    final i = _cursor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.telemetryTitle,
                    style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: l10n.passMapOpen,
                  onPressed: () => widget.onOpenMap(_channel),
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
            Text(
              l10n.telemetryHelp,
              style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ch in _channels)
                  ChoiceChip(
                    label: Text(ch.label(l10n)),
                    selected: _channel == ch,
                    onSelected: (_) => setState(() => _channel = ch),
                    selectedColor: OffroadTheme.track,
                    labelStyle: TextStyle(
                      color: _channel == ch ? Colors.black : OffroadTheme.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 26,
              child: i == null
                  ? null
                  : Text(
                      '${t.dist[i].toStringAsFixed(0)} m · '
                      '${t.kmh[i].toStringAsFixed(0)} km/h · '
                      '${t.lean[i].abs().toStringAsFixed(0)}° · '
                      '${TraceChannel.longG.format(t.longG[i])} g',
                      style: OffroadTheme.hud(16),
                    ),
            ),
            SizedBox(
              height: 170,
              child: ChannelChart(
                trace: t,
                channel: _channel,
                brakes: _brakes,
                cursor: i,
                onScrub: (v) => setState(() => _cursor = v),
              ),
            ),
            if (_channel.estimated)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.channelEstimatedNote,
                  style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GgCard extends StatelessWidget {
  const _GgCard({required this.trace});
  final PassTrace trace;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ggTitle,
              style: GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.ggHelp,
              style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: GgDiagram(
                  trace: trace,
                  labels: (l10n.ggBrake, l10n.ggThrottle, l10n.hudLeft, l10n.hudRight),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                for (var i = 0; i < 3; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: OffroadTheme.sector(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text('S${i + 1}', style: OffroadTheme.label()),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.channelEstimatedNote,
              style: const TextStyle(color: OffroadTheme.textFaint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.analysis, required this.pass});
  final PassAnalysis analysis;
  final TrainingPass pass;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = analysis.durationDeltaS;
    final isBest = d.abs() < 0.05;
    final color = isBest
        ? OffroadTheme.sector(2)
        : (d > 0 ? OffroadTheme.sector(0) : OffroadTheme.sector(2));
    final label = isBest
        ? l10n.offroadFastest
        : (d > 0
            ? l10n.offroadSlowerBy(d.toStringAsFixed(1))
            : l10n.offroadFasterBy((-d).toStringAsFixed(1)));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(OffroadTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            isBest ? Icons.emoji_events_rounded : Icons.timelapse_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                  ),
                ),
                Text(
                  isBest
                      ? l10n.offroadReferencePass
                      : l10n.offroadVsPass(analysis.fastestPass.id),
                  style: const TextStyle(
                    color: OffroadTheme.textMuted,
                    fontSize: 13,
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

class _SectorRow extends StatelessWidget {
  const _SectorRow({required this.delta, this.circuit});
  final SectorDelta delta;
  final Circuit? circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final i = int.tryParse(delta.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final color = OffroadTheme.sector(i - 1);
    final d = delta.deltaS;
    Color deltaColor;
    String deltaText;
    if (delta.partial || d == null) {
      deltaColor = OffroadTheme.textFaint;
      deltaText = l10n.offroadNotComparable;
    } else if (delta.isBest) {
      deltaColor = OffroadTheme.sector(2);
      deltaText = l10n.offroadBestMark;
    } else if (d > 0) {
      deltaColor = OffroadTheme.sector(0);
      deltaText = '+${d.toStringAsFixed(2)} s';
    } else {
      deltaColor = OffroadTheme.sector(2);
      deltaText = '${d.toStringAsFixed(2)} s';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (circuit != null)
              SizedBox(
                width: 72,
                height: 56,
                child: CircuitSilhouette(
                  circuit: circuit!,
                  highlight: i - 1,
                ),
              ),
            if (circuit != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          delta.name,
                          style: OffroadTheme.hud(16, color: Colors.black),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        deltaText,
                        style: GoogleFonts.rajdhani(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: deltaColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    d == null || delta.partial
                        ? '${delta.timeS.toStringAsFixed(2)} s'
                            '${delta.note != null ? ' · ${delta.note}' : ''}'
                        : '${delta.timeS.toStringAsFixed(2)} s  ·  '
                            '${l10n.offroadBestShort} ${delta.bestS!.toStringAsFixed(2)} s'
                            '${delta.bestPassId != null ? ' (${delta.bestPassId})' : ''}',
                    style: const TextStyle(
                      color: OffroadTheme.textMuted,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactorCard extends StatelessWidget {
  const _FactorCard({required this.factor});
  final PaceFactor factor;

  @override
  Widget build(BuildContext context) {
    final color = switch (factor.kind) {
      'good' => OffroadTheme.sector(2),
      'bad' => OffroadTheme.sector(0),
      _ => OffroadTheme.sector(1),
    };
    final icon = switch (factor.kind) {
      'good' => Icons.check_circle_rounded,
      'bad' => Icons.trending_down_rounded,
      _ => Icons.info_outline_rounded,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    factor.title,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    factor.body,
                    style: const TextStyle(
                      color: OffroadTheme.textMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrakeRow extends StatelessWidget {
  const _BrakeRow({required this.brake});
  final PassBrake brake;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              brake.sector,
              style: OffroadTheme.label(color: OffroadTheme.track),
            ),
          ),
          Expanded(
            child: Text(
              '${brake.lapM.toStringAsFixed(0)} m · '
              '${brake.vIn.toStringAsFixed(0)}→${brake.vOut.toStringAsFixed(0)} km/h · '
              '${brake.peakG.toStringAsFixed(2)} g',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
