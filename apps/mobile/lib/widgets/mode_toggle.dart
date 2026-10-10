import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_mode.dart';
import '../l10n/l10n_ext.dart';
import '../theme/app_theme.dart';
import '../theme/offroad_theme.dart';

/// ON / OFF pill shown in the header of both home screens.
class ModeToggle extends ConsumerWidget {
  const ModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final off = mode == AppMode.off;
    final accent = off ? OffroadTheme.track : AppTheme.signal;
    return Semantics(
      button: true,
      label: context.l10n.modeToggleSemantics,
      child: GestureDetector(
        onTap: () => ref.read(appModeProvider.notifier).toggle(),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: off ? OffroadTheme.panel : AppTheme.asphaltElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Segment(label: 'ON', selected: !off, color: AppTheme.signal),
              _Segment(label: 'OFF', selected: off, color: OffroadTheme.track),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.color,
  });

  final String label;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: selected ? Colors.black : AppTheme.steel,
        ),
      ),
    );
  }
}
