import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/ride.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../theme/app_theme.dart';

/// Assign route + share toggle for a completed ride.
class RideSharePanel extends ConsumerWidget {
  const RideSharePanel({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final routesAsync = ref.watch(routesListProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shareRideTitle,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.shareRideHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.shareThisRide),
            value: ride.isShared,
            onChanged: (v) async {
              final updated = ride.copyWith(isShared: v);
              await ref.read(rideDatabaseProvider).upsertRide(updated);
              await ref.read(rideSyncServiceProvider).syncRide(ride.id);
              ref.invalidate(rideProvider(ride.id));
              ref.invalidate(overlappingPeersProvider(ride.id));
            },
          ),
          const SizedBox(height: 4),
          Text(
            l10n.assignRoute,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          routesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(
              l10n.cloudUnavailable,
              style: const TextStyle(color: AppTheme.steel, fontSize: 12),
            ),
            data: (routes) {
              return DropdownButtonFormField<String?>(
                initialValue: ride.routeId,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.asphalt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                hint: Text(l10n.noRouteAssigned),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noRouteAssigned),
                  ),
                  for (final r in routes)
                    DropdownMenuItem<String?>(
                      value: r.id,
                      child: Text(r.name),
                    ),
                ],
                onChanged: (routeId) async {
                  final updated = routeId == null
                      ? ride.copyWith(clearRouteId: true)
                      : ride.copyWith(routeId: routeId);
                  await ref.read(rideDatabaseProvider).upsertRide(updated);
                  await ref.read(rideSyncServiceProvider).syncRide(ride.id);
                  ref.invalidate(rideProvider(ride.id));
                  ref.invalidate(overlappingPeersProvider(ride.id));
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _quickCreate(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.createRoute),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickCreate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(l10n.createRoute),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.routeNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.saveName),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final route = await ref.read(routeServiceProvider).createRoute(
          name: ctrl.text,
          isShared: true,
        );
    final updated = ride.copyWith(routeId: route.id, isShared: true);
    await ref.read(rideDatabaseProvider).upsertRide(updated);
    await ref.read(rideSyncServiceProvider).syncRide(ride.id);
    ref.invalidate(routesListProvider);
    ref.invalidate(rideProvider(ride.id));
    ref.invalidate(overlappingPeersProvider(ride.id));
  }
}
