import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/bikes/triumph_catalog.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/bike_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../home/home_nav_icons.dart';

/// Pick the rider's Triumph (or other) from the garage catalog.
class BikePickerScreen extends ConsumerWidget {
  const BikePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(riderBikeProvider);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.bikePickerTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l10n.bikePickerHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppTheme.line.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: const AppMotoIcon(
                    size: 28,
                    color: RideVizPalette.leanLeft,
                  ),
                  title: Text(
                    selected.label,
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    selected.subtitle,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 12,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(riderBikeProvider.notifier).clear(),
                    child: Text(l10n.bikeClear),
                  ),
                ),
              ),
            ),
          for (final family in BikeFamily.values) ...[
            if (TriumphCatalog.byFamily(family).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _familyLabel(l10n, family),
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.mist,
                ),
              ),
              const SizedBox(height: 8),
              for (final bike in TriumphCatalog.byFamily(family))
                _BikeTile(
                  bike: bike,
                  selected: selected?.id == bike.id,
                  onTap: () async {
                    await ref.read(riderBikeProvider.notifier).select(bike);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _familyLabel(AppLocalizations l10n, BikeFamily f) => switch (f) {
        BikeFamily.naked => l10n.bikeFamilyNaked,
        BikeFamily.adventure => l10n.bikeFamilyAdventure,
        BikeFamily.classic => l10n.bikeFamilyClassic,
        BikeFamily.sport => l10n.bikeFamilySport,
        BikeFamily.cruiser => l10n.bikeFamilyCruiser,
        BikeFamily.other => l10n.bikeFamilyOther,
      };
}

class _BikeTile extends StatelessWidget {
  const _BikeTile({
    required this.bike,
    required this.selected,
    required this.onTap,
  });

  final BikeModel bike;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? RideVizPalette.leanLeft.withValues(alpha: 0.18)
            : AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? RideVizPalette.leanLeft : AppTheme.steel,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bike.label,
                        style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        bike.subtitle,
                        style: const TextStyle(
                          color: AppTheme.steel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
