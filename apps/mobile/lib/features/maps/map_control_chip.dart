import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';

/// Dark map overlay button (zoom, fit, my-location).
class MapControlChip extends StatelessWidget {
  const MapControlChip({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.asphaltElevated.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
      ),
    );
  }
}

/// GPS recenter chip — same look as [MapControlChip].
class MapMyLocationChip extends StatelessWidget {
  const MapMyLocationChip({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MapControlChip(
      icon: Icons.my_location,
      onPressed: onPressed,
      tooltip: context.l10n.myLocation,
    );
  }
}
