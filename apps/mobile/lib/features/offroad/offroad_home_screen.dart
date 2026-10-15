import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/offroad_theme.dart';
import '../../widgets/mode_toggle.dart';
import '../../widgets/rider_alias_chip.dart';
import '../settings/logger_hardware_screen.dart';
import 'circuits_list_screen.dart';
import 'session_model.dart';
import 'sessions_list_screen.dart';

/// OFF home: performance strip + Circuits + Sessions (mirrors ON garage layout).
class OffroadHomeScreen extends ConsumerWidget {
  const OffroadHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final perf = ref.watch(offroadPerformanceProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: ModeToggle(),
                ),
                const SizedBox(width: 8),
                const RiderProfileButton(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.offroadTagline,
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                color: OffroadTheme.textMuted,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            _PerformanceStrip(perf: perf),
            const SizedBox(height: 20),
            _HomeAction(
              icon: Icons.map_rounded,
              title: l10n.offroadCircuitsTitle,
              subtitle: l10n.offroadCircuitsSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CircuitsListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _HomeAction(
              icon: Icons.school_rounded,
              title: l10n.offroadSessionsTitle,
              subtitle: l10n.offroadSessionsSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SessionsListScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _HomeAction(
              icon: Icons.bluetooth_searching_rounded,
              title: l10n.offroadMetricaTitle,
              subtitle: l10n.offroadMetricaSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoggerHardwareScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceStrip extends StatelessWidget {
  const _PerformanceStrip({required this.perf});
  final OffroadPerformance perf;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OffroadTheme.panel,
            Color.lerp(OffroadTheme.field, OffroadTheme.track, 0.14)!,
            Color.lerp(OffroadTheme.panel, OffroadTheme.sector(1), 0.08)!,
          ],
        ),
        border: Border.all(color: OffroadTheme.track.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.performanceLabel,
            style: GoogleFonts.exo2(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: OffroadTheme.track,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.offroadStatSessions,
                  value: '${perf.sessions}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.offroadPasses,
                  value: '${perf.passes}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.statDistance,
                  value: perf.distanceKm == 0
                      ? '--'
                      : '${perf.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: l10n.statTopSpeed,
                  value: perf.vmaxKmh == null
                      ? '--'
                      : perf.vmaxKmh!.toStringAsFixed(0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            color: OffroadTheme.textFaint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.rajdhani(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(OffroadTheme.radiusLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: OffroadTheme.track.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(OffroadTheme.radiusMd),
                ),
                child: Icon(icon, color: OffroadTheme.track, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.exo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: OffroadTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: OffroadTheme.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big number + small unit + label, shared by OFF screens.
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
