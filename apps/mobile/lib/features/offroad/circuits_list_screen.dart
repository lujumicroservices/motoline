import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import 'circuit_detail_screen.dart';
import 'circuit_model.dart';
import 'offroad_home_screen.dart' show CircuitStat;
import 'widgets/circuit_silhouette.dart';

/// Mapped circuits available to the rider.
class CircuitsListScreen extends ConsumerWidget {
  const CircuitsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final circuits = ref.watch(circuitsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offroadCircuitsTitle)),
      body: circuits.when(
        data: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) => _CircuitCard(circuit: list[i]),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _CircuitCard extends StatelessWidget {
  const _CircuitCard({required this.circuit});
  final Circuit circuit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = circuit;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(c.mappedOn);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CircuitDetailScreen(circuit: c),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 170,
              color: OffroadTheme.field,
              padding: const EdgeInsets.all(12),
              child: CircuitSilhouette(circuit: c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: GoogleFonts.exo2(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    c.place,
                    style: const TextStyle(
                      color: OffroadTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircuitStat(
                        value: c.lengthM.toStringAsFixed(0),
                        unit: 'm',
                        label: l10n.circuitStatLap,
                        size: 26,
                      ),
                      CircuitStat(
                        value: '${c.sectors.length}',
                        label: l10n.circuitStatSectors,
                        size: 26,
                      ),
                      CircuitStat(
                        value: c.elevDrop.toStringAsFixed(0),
                        unit: 'm',
                        label: l10n.circuitStatDrop,
                        size: 26,
                      ),
                      CircuitStat(
                        value: c.widthMedian.toStringAsFixed(1),
                        unit: 'm',
                        label: l10n.circuitStatWidth,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${l10n.circuitMappedOn(date)} · '
                    '${c.ccw ? l10n.circuitDirectionCcw : l10n.circuitDirectionCw}',
                    style: OffroadTheme.label(color: OffroadTheme.textFaint),
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
