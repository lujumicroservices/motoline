import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'offroad_home_screen.dart' show CircuitStat;
import 'pass_detail_screen.dart';
import 'session_model.dart';

/// Training session: passes of the day on one circuit + coaching insights.
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});

  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = session;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.circuitName),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.offroadTabCoaching),
              Tab(text: l10n.offroadTabPasses),
              Tab(text: l10n.offroadTabSummary),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CoachingTab(session: s),
            _PassesTab(session: s),
            _SummaryTab(session: s),
          ],
        ),
      ),
    );
  }
}

class _CoachingTab extends StatelessWidget {
  const _CoachingTab({required this.session});
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = session;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          s.title,
          style: GoogleFonts.exo2(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          s.subtitle,
          style: const TextStyle(color: OffroadTheme.textMuted),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.offroadWhatWentWell,
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: OffroadTheme.sector(2),
          ),
        ),
        const SizedBox(height: 8),
        for (final i in s.goods) _InsightCard(insight: i),
        const SizedBox(height: 20),
        Text(
          l10n.offroadWhatToImprove,
          style: GoogleFonts.exo2(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: OffroadTheme.sector(0),
          ),
        ),
        const SizedBox(height: 8),
        for (final i in s.bads) _InsightCard(insight: i),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final TrainingInsight insight;

  @override
  Widget build(BuildContext context) {
    final good = insight.isGood;
    final color = good ? OffroadTheme.sector(2) : OffroadTheme.sector(0);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              good ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (insight.sector != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            insight.sector!,
                            style: OffroadTheme.label(color: color),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insight.body,
                    style: const TextStyle(
                      color: OffroadTheme.textMuted,
                      height: 1.35,
                      fontSize: 14,
                    ),
                  ),
                  if (insight.passId != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Pasada ${insight.passId}',
                      style: OffroadTheme.label(color: OffroadTheme.textFaint),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassesTab extends StatelessWidget {
  const _PassesTab({required this.session});
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: session.passes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = session.passes[i];
        final best = p.id ==
            session.passes
                .reduce((a, b) => a.durationS <= b.durationS ? a : b)
                .id;
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(OffroadTheme.radiusLg),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PassDetailScreen(
                  session: session,
                  pass: p,
                  passIndex: i,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${l10n.offroadPass} ${i + 1}',
                        style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.id,
                        style: OffroadTheme.label(color: OffroadTheme.track),
                      ),
                      if (best) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: OffroadTheme.track,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.offroadFastest,
                            style: OffroadTheme.label(color: Colors.black),
                          ),
                        ),
                      ] else
                        const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: OffroadTheme.textFaint,
                      ),
                    ],
                  ),
                  Text(
                    '${p.startLocal} – ${p.endLocal}',
                    style: const TextStyle(
                      color: OffroadTheme.textFaint,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircuitStat(
                        value: (p.durationS / 60).toStringAsFixed(1),
                        unit: 'min',
                        label: l10n.offroadDuration,
                        size: 24,
                      ),
                      CircuitStat(
                        value: p.vmaxKmh.toStringAsFixed(0),
                        unit: 'km/h',
                        label: l10n.statTopSpeed,
                        size: 24,
                      ),
                      CircuitStat(
                        value: '${(100 - p.pctOutside).toStringAsFixed(0)}%',
                        label: l10n.offroadInsideTrack,
                        size: 24,
                      ),
                      CircuitStat(
                        value: p.leanMax.toStringAsFixed(0),
                        unit: '°',
                        label: l10n.statPeakLean,
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.offroadSectors, style: OffroadTheme.label()),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sec in p.sectors)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: OffroadTheme.field,
                            borderRadius: BorderRadius.circular(
                              OffroadTheme.radiusSm,
                            ),
                            border: Border.all(
                              color: sec.partial ||
                                      (sec.note?.isNotEmpty ?? false)
                                  ? OffroadTheme.sector(0).withValues(alpha: 0.6)
                                  : OffroadTheme.panelBorder,
                            ),
                          ),
                          child: Text(
                            '${sec.name}${sec.partial ? '*' : ''}: '
                            '${sec.timeS.toStringAsFixed(1)} s',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.offroadTapPassDetail,
                    style: OffroadTheme.label(color: OffroadTheme.track),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.session});
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = session.summary;
    final m = session.mapping;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.offroadSessionTotals,
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircuitStat(
                      value: '${s.passes}',
                      label: l10n.offroadPasses,
                      size: 28,
                    ),
                    CircuitStat(
                      value: s.distanceKm.toStringAsFixed(2),
                      unit: 'km',
                      label: l10n.statDistance,
                      size: 28,
                    ),
                    CircuitStat(
                      value: (s.bestDurationS / 60).toStringAsFixed(1),
                      unit: 'min',
                      label: l10n.offroadBestPass,
                      size: 28,
                    ),
                    CircuitStat(
                      value: s.vmaxKmh.toStringAsFixed(0),
                      unit: 'km/h',
                      label: l10n.statTopSpeed,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _row(l10n.offroadBestS2, '${s.bestS2S.toStringAsFixed(2)} s'),
                _row(l10n.offroadBestS3, '${s.bestS3S.toStringAsFixed(2)} s'),
                _row(
                  l10n.offroadTheoreticalPartial,
                  '${s.theoreticalPartialS.toStringAsFixed(2)} s',
                ),
                _row(l10n.offroadFlyingLaps, '${s.flyingLaps}'),
                _row(
                  l10n.offroadBestLine,
                  '${(100 - s.bestOutsidePct).toStringAsFixed(1)} % '
                  '${l10n.offroadInsideTrack.toLowerCase()}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.offroadMappingUsed,
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _row(l10n.mappingDate, '${m['date']}'),
                _row(
                  l10n.mappingEdgeOuter,
                  'Logger ${m['outer_logger']}',
                ),
                _row(
                  l10n.mappingEdgeInner,
                  'Logger ${m['inner_logger']}',
                ),
                _row(l10n.circuitStatLap, '${m['length_m']} m'),
                _row(
                  l10n.circuitStatWidth,
                  '${m['width_median_m']} m '
                  '(${l10n.mappingMedian})',
                ),
                _row('RLC1', '${m['geometry']}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: OffroadTheme.label())),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
