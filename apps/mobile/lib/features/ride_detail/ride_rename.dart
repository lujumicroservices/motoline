import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/ride.dart';
import '../../core/services/ride_place_name_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';

/// Dialog to set a custom ride name or fill from GPS start/end places.
Future<void> showRideRenameDialog(
  BuildContext context,
  WidgetRef ref,
  Ride ride,
) async {
  final l10n = context.l10n;
  final ctrl = TextEditingController(text: ride.title ?? '');
  final action = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.asphaltElevated,
      title: Text(l10n.rideNameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.rideNameHint,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rideNameHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'geo'),
          child: Text(l10n.nameFromMap),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, 'save'),
          child: Text(l10n.saveName),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;

  try {
    String? title;
    if (action == 'geo') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.lookingUpPlaces)),
      );
      final points = await ref.read(ridePointsProvider(ride.id).future);
      title = await RidePlaceNameService().titleFromTrack(points);
      if (title == null || title.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.couldNotResolvePlaces)),
        );
        return;
      }
    } else {
      title = ctrl.text.trim();
      if (title.isEmpty) title = null;
    }
    final updated = title == null
        ? ride.copyWith(clearTitle: true)
        : ride.copyWith(title: title);
    await ref.read(rideDatabaseProvider).upsertRide(updated);
    unawaited(ref.read(rideSyncServiceProvider).syncRide(ride.id));
    ref.invalidate(rideProvider(ride.id));
    ref.invalidate(ridesListProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          title == null ? l10n.rideTitleCleared : l10n.rideNamed(title),
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}
