import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/friends/friends_screen.dart';
import '../features/settings/settings_screen.dart';
import '../l10n/l10n_ext.dart';
import '../providers/alias_provider.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../theme/ride_viz_palette.dart';

/// Compact chip with person icon + alias — used on secondary screens.
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
                  style: GoogleFonts.exo2(
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

/// Top-right circular profile control — initial from alias, opens account/settings.
class RiderProfileButton extends ConsumerWidget {
  const RiderProfileButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alias = ref.watch(riderAliasProvider).trim();
    final permanent = ref.watch(hasPermanentIdentityProvider);
    final authLabel = ref.watch(authServiceProvider).displayLabel?.trim();
    final label = alias.isNotEmpty
        ? alias
        : (authLabel != null && authLabel.isNotEmpty ? authLabel : '');
    final initial = label.isNotEmpty
        ? String.fromCharCode(label.runes.first).toUpperCase()
        : null;

    return Tooltip(
      message: label.isEmpty ? l10n.accountSection : label,
      child: Material(
        color: AppTheme.asphaltElevated,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: permanent
                    ? AppTheme.line.withValues(alpha: 0.55)
                    : AppTheme.mist.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            child: Center(
              child: initial == null
                  ? Icon(
                      Icons.person_outline,
                      size: 22,
                      color: RideVizPalette.leanLeft,
                    )
                  : Text(
                      initial,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.mist,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
