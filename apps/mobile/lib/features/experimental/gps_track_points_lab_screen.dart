import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_build_info.dart';
import '../../core/models/ride.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import 'gps_track_points_map_screen.dart';

/// Experimental lab: inspect raw GPS samples that form a ride track.
class GpsTrackPointsLabScreen extends ConsumerWidget {
  const GpsTrackPointsLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(ridesListProvider);
    final buildAsync = ref.watch(appBuildInfoProvider);
    final dateFmt = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gpsTrackPointsLabTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            l10n.gpsTrackPointsLabIntro,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 14),
          ),
          const SizedBox(height: 12),
          buildAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (info) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: info.isExperimental
                    ? AppTheme.lineHot.withValues(alpha: 0.12)
                    : AppTheme.asphaltElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: info.isExperimental
                      ? AppTheme.lineHot.withValues(alpha: 0.35)
                      : AppTheme.mist.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                info.fullLine,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.mist,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.gpsTrackPointsLabPickRide,
            style: GoogleFonts.rajdhani(
              color: AppTheme.mist,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ridesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('$e', style: const TextStyle(color: AppTheme.steel)),
            data: (rides) {
              final eligible = rides
                  .where(
                    (r) =>
                        r.status == RideStatus.completed && r.pointCount >= 2,
                  )
                  .toList();
              if (eligible.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l10n.gpsTrackPointsLabEmpty,
                    style: GoogleFonts.rajdhani(color: AppTheme.steel),
                  ),
                );
              }
              return Column(
                children: [
                  for (final ride in eligible)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.route, color: AppTheme.line),
                      title: Text(
                        ride.displayTitle(dateFormat: dateFmt.format),
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        l10n.gpsTrackPointsLabRideMeta(
                          ride.pointCount,
                          (ride.distanceMeters / 1000).toStringAsFixed(1),
                        ),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GpsTrackPointsMapScreen(
                              rideId: ride.id,
                              rideTitle: ride.displayTitle(
                                dateFormat: dateFmt.format,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
