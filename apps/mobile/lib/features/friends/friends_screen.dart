import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/cloud_models.dart';
import '../../core/utils/geo_utils.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/alias_provider.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _nameController = TextEditingController();
  bool _nameSeeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendsAsync = ref.watch(friendsListProvider);
    final meAsync = ref.watch(myProfileProvider);

    meAsync.whenData((profile) {
      final cloudName = profile?.displayName?.trim() ?? '';
      if (!_nameSeeded) {
        _nameSeeded = true;
        if (cloudName.isNotEmpty) {
          _nameController.text = cloudName;
        }
      } else if (cloudName.isNotEmpty &&
          _nameController.text.trim() != cloudName &&
          !_saving) {
        // Keep field in sync when Google link updates profiles.display_name.
        _nameController.text = cloudName;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.friends,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsListProvider);
          ref.invalidate(myProfileProvider);
          await ref.read(friendsListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              l10n.friendsSubtitle,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.yourName,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: l10n.nameHint,
                      filled: true,
                      fillColor: AppTheme.asphaltElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _saving ? null : _saveName,
                  child: Text(l10n.saveName),
                ),
              ],
            ),
            const SizedBox(height: 28),
            friendsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) {
                final msg = '$e';
                final anonymousOff = msg.contains('anonymous_disabled') ||
                    msg.toLowerCase().contains('anonymous');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        anonymousOff
                            ? l10n.cloudAnonymousOff
                            : l10n.cloudUnavailable,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          height: 1.4,
                        ),
                      ),
                      if (!anonymousOff) ...[
                        const SizedBox(height: 8),
                        Text(
                          msg.replaceFirst('Bad state: ', ''),
                          style: GoogleFonts.rajdhani(
                            color: AppTheme.steel.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () {
                          ref.invalidate(friendsListProvider);
                          ref.invalidate(myProfileProvider);
                        },
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                );
              },
              data: (friends) {
                if (friends.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      l10n.friendsEmpty,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        height: 1.4,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final friend in friends)
                      _FriendTile(friend: friend),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      await ref.read(riderAliasProvider.notifier).setAlias(name);
      await ref.read(socialRepositoryProvider).updateDisplayName(name);
      ref.invalidate(myProfileProvider);
      ref.invalidate(friendsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nameSaved)),
      );
    } catch (e) {
      // Still keep local alias if cloud fails.
      await ref
          .read(riderAliasProvider.notifier)
          .setAlias(_nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend});

  final RiderProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      color: AppTheme.asphaltElevated,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.line.withValues(alpha: 0.25),
          child: Text(
            friend.label.isNotEmpty ? friend.label[0].toUpperCase() : '?',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          friend.label,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          l10n.friendRides,
          style: const TextStyle(color: AppTheme.steel, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.steel),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FriendRidesScreen(friend: friend),
            ),
          );
        },
      ),
    );
  }
}

class FriendRidesScreen extends ConsumerWidget {
  const FriendRidesScreen({super.key, required this.friend});

  final RiderProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ridesAsync = ref.watch(friendRidesProvider(friend.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          friend.label,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.friendRidesEmpty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.steel),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ride = rides[i];
              return ListTile(
                tileColor: AppTheme.asphaltElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  DateFormat('EEE · MMM d · HH:mm').format(ride.startedAt.toLocal()),
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${ride.distanceKm.toStringAsFixed(1)} km · '
                  '${formatDuration(ride.duration)} · '
                  '${ride.maxSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
                  style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                ),
                onTap: () {
                  // Friend-only view: open compare against local rides via peers list
                  // from Ride Lab is primary; here show metrics sheet.
                  showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: AppTheme.asphaltElevated,
                    builder: (_) => _FriendRideSheet(ride: ride),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FriendRideSheet extends StatelessWidget {
  const _FriendRideSheet({required this.ride});

  final CloudRideSummary ride;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.riderLabel,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat.yMMMd().add_jm().format(ride.startedAt.toLocal()),
            style: const TextStyle(color: AppTheme.steel),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _chip(l10n.distance, '${ride.distanceKm.toStringAsFixed(2)} km'),
              _chip(l10n.duration, formatDuration(ride.duration)),
              _chip(
                l10n.maxSpeed,
                '${ride.maxSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
              ),
              _chip(
                l10n.avgSpeed,
                '${ride.avgSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
              ),
              _chip(
                l10n.maxLR,
                '${ride.maxLeanLeftDeg?.toStringAsFixed(0) ?? "—"}° / '
                '${ride.maxLeanRightDeg?.toStringAsFixed(0) ?? "—"}°',
              ),
              _chip(l10n.lineScore, '${ride.lineScore ?? "—"}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.comparePickPeer,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.steel, fontSize: 11)),
        Text(
          value,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
