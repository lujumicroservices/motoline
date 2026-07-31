import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_ext.dart';
import '../providers/alias_provider.dart';
import '../theme/app_theme.dart';
import '../theme/ride_viz_palette.dart';
import '../features/friends/friends_screen.dart';

/// Shows the rider alias everywhere — taps through to set name in Friends.
class RiderAliasChip extends ConsumerWidget {
  const RiderAliasChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alias = ref.watch(riderAliasProvider);
    final label = alias.isEmpty ? l10n.setYourAlias : alias;

    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FriendsScreen()),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: compact ? 16 : 18,
                color: RideVizPalette.leanLeft,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 13,
                    color: alias.isEmpty ? AppTheme.steel : AppTheme.mist,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
