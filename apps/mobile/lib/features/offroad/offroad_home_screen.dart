import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import '../../widgets/mode_toggle.dart';
import '../../widgets/rider_alias_chip.dart';
import 'circuit_detail_screen.dart';
import 'circuit_model.dart';
import 'widgets/circuit_silhouette.dart';

/// OFF mode home: the circuits the rider has, starting with 8 Horas.
class OffroadHomeScreen extends ConsumerWidget {
  const OffroadHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final circuits = ref.watch(circuitsProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(OffroadTheme.radiusSm),
                  child: Image.asset(
                    'assets/branding/metrica_wheelie_96.png',
                    width: 44,
                    height: 44,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RiderLab',
                        style: GoogleFonts.exo2(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        l10n.offroadBrandTag,
                        style: OffroadTheme.label(color: OffroadTheme.track),
                      ),
                    ],
                  ),
                ),
                const ModeToggle(),
                const SizedBox(width: 8),
                const RiderProfileButton(),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.offroadHomeTitle,
              style: GoogleFonts.exo2(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.offroadHomeSubtitle,
              style: const TextStyle(color: OffroadTheme.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 16),
            circuits.when(
              data: (list) => Column(
                children: [
                  for (final c in list) ...[
                    _CircuitCard(circuit: c),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
            ),
          ],
        ),
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
              height: 190,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.place,
                    style: const TextStyle(
                      color: OffroadTheme.textMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircuitStat(
                        value: c.lengthM.toStringAsFixed(0),
                        unit: 'm',
                        label: l10n.circuitStatLap,
                      ),
                      CircuitStat(
                        value: '${c.sectors.length}',
                        label: l10n.circuitStatSectors,
                      ),
                      CircuitStat(
                        value: c.elevDrop.toStringAsFixed(0),
                        unit: 'm',
                        label: l10n.circuitStatDrop,
                      ),
                      CircuitStat(
                        value: c.widthMedian.toStringAsFixed(1),
                        unit: 'm',
                        label: l10n.circuitStatWidth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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

/// Big number + small unit + label, the OFF-mode stat cell.
class CircuitStat extends StatelessWidget {
  const CircuitStat({
    super.key,
    required this.value,
    required this.label,
    this.unit,
    this.size = 30,
  });

  final String value;
  final String label;
  final String? unit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: OffroadTheme.hud(size)),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: OffroadTheme.hud(
                      size * 0.5,
                      color: OffroadTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: OffroadTheme.label()),
        ],
      ),
    );
  }
}
