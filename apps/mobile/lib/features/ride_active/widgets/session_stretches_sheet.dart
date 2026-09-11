import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/ride_stretch.dart';
import '../../../core/utils/geo_utils.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';

Future<void> showSessionStretchesSheet(
  BuildContext context, {
  required List<RideStretch> stretches,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTheme.asphalt,
    builder: (context) {
      if (stretches.isEmpty) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Text(
            l10n.armedSessionStretchesEmpty,
            style: const TextStyle(color: AppTheme.steel, fontSize: 14),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: stretches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final stretch = stretches[stretches.length - 1 - i];
          return SessionStretchTile(stretch: stretch);
        },
      );
    },
  );
}

class SessionStretchTile extends StatelessWidget {
  const SessionStretchTile({super.key, required this.stretch});

  final RideStretch stretch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final time = DateFormat.Hm().format(stretch.startedAt.toLocal());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.line.withValues(alpha: 0.2),
            child: Text(
              '${stretch.index}',
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                color: AppTheme.line,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.armedSessionStretchN(stretch.index),
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: const TextStyle(color: AppTheme.steel, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${stretch.distanceKm.toStringAsFixed(2)} km',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatDuration(stretch.duration),
            style: const TextStyle(color: AppTheme.steel, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
