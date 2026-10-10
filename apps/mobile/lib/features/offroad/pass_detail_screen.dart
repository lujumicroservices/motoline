import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_model.dart';
import 'offroad_home_screen.dart' show CircuitStat;
import 'pass_analysis.dart';
import 'session_model.dart';
import 'widgets/circuit_silhouette.dart';

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
