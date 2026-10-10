import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'session_detail_screen.dart';
import 'session_model.dart';

class SessionsListScreen extends ConsumerWidget {
  const SessionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(trainingSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offroadSessionsTitle)),
      body: sessions.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.offroadSessionsEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: OffroadTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _SessionCard(session: list[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = session;
    final date = DateFormat.yMMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(s.date);
    final goods = s.goods.length;
    final bads = s.bads.length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(OffroadTheme.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(session: s),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.circuitName,
                style: OffroadTheme.label(color: OffroadTheme.track),
              ),
              const SizedBox(height: 4),
              Text(
                s.title,
                style: GoogleFonts.exo2(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                  color: OffroadTheme.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _chip(
                    Icons.route_rounded,
                    '${s.summary.passes} ${l10n.offroadPasses}',
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    Icons.timer_outlined,
                    '${(s.summary.bestDurationS / 60).toStringAsFixed(1)} min',
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    Icons.speed_rounded,
                    '${s.summary.vmaxKmh.toStringAsFixed(0)} km/h',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_rounded,
                      size: 16, color: OffroadTheme.sector(2)),
                  const SizedBox(width: 4),
                  Text(
                    l10n.offroadInsightCountGood(goods),
                    style: OffroadTheme.label(color: OffroadTheme.sector(2)),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.thumb_down_alt_rounded,
                      size: 16, color: OffroadTheme.sector(0)),
                  const SizedBox(width: 4),
                  Text(
                    l10n.offroadInsightCountBad(bads),
                    style: OffroadTheme.label(color: OffroadTheme.sector(0)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: OffroadTheme.field,
        borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
        border: Border.all(color: OffroadTheme.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: OffroadTheme.track),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
