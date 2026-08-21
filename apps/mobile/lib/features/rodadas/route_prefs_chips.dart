import 'package:flutter/material.dart';

import '../../core/routing/route_prefs.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';

class RoutePrefsChips extends StatelessWidget {
  const RoutePrefsChips({
    super.key,
    required this.prefs,
    required this.onChanged,
  });

  final RoutePrefs prefs;
  final ValueChanged<RoutePrefs> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          label: Text(l10n.routePrefTolls),
          selected: !prefs.avoidTolls,
          selectedColor: AppTheme.lineHot.withValues(alpha: 0.28),
          onSelected: (allow) => onChanged(prefs.copyWith(avoidTolls: !allow)),
        ),
        FilterChip(
          label: Text(l10n.routePrefHighway),
          selected: prefs.allowHighway,
          selectedColor: AppTheme.line.withValues(alpha: 0.28),
          onSelected: (v) => onChanged(prefs.copyWith(allowHighway: v)),
        ),
        FilterChip(
          label: Text(l10n.routePrefStreet),
          selected: prefs.allowStreet,
          selectedColor: AppTheme.line.withValues(alpha: 0.28),
          onSelected: (v) => onChanged(prefs.copyWith(allowStreet: v)),
        ),
        FilterChip(
          label: Text(l10n.routePrefOffroad),
          selected: prefs.allowOffroad,
          selectedColor: AppTheme.signal.withValues(alpha: 0.22),
          onSelected: (v) => onChanged(prefs.copyWith(allowOffroad: v)),
        ),
      ],
    );
  }
}
