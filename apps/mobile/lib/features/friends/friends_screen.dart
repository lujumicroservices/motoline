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
import '../rodadas/rodada_providers.dart';
import '../rodadas/rodadas_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _nameSeeded = false;
  bool _saving = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _invalidateSocial() {
    ref.invalidate(friendsListProvider);
    ref.invalidate(incomingFriendRequestsProvider);
    ref.invalidate(outgoingFriendRequestsProvider);
    ref.invalidate(myProfileProvider);
    if (_searchQuery.length >= 2) {
      ref.invalidate(riderSearchProvider(_searchQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final friendsAsync = ref.watch(friendsListProvider);
    final incomingAsync = ref.watch(incomingFriendRequestsProvider);
    final outgoingAsync = ref.watch(outgoingFriendRequestsProvider);
    final meAsync = ref.watch(myProfileProvider);
    final searchAsync = _searchQuery.length >= 2
        ? ref.watch(riderSearchProvider(_searchQuery))
        : null;

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
          _invalidateSocial();
          await ref.read(friendsListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text(
              l10n.friendsHelp,
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
            const SizedBox(height: 24),
            Text(
              l10n.findRiders,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchByNameHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.asphaltElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v.trim());
              },
            ),
            if (searchAsync != null) ...[
              const SizedBox(height: 8),
              searchAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (hits) {
                  if (hits.isEmpty) {
                    return Text(
                      l10n.noRidersFound,
                      style: GoogleFonts.rajdhani(color: AppTheme.steel),
                    );
                  }
                  return Column(
                    children: [
                      for (final rider in hits)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(rider.label),
                          trailing: FilledButton.tonal(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(friendshipRepositoryProvider)
                                    .requestFriend(rider.id);
                                _invalidateSocial();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.friendRequestSent(rider.label),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$e')),
                                );
                              }
                            },
                            child: Text(l10n.addFriend),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            incomingAsync.when(
              data: (reqs) {
                if (reqs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.friendRequests,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final r in reqs)
                      Card(
                        color: AppTheme.asphaltElevated,
                        child: ListTile(
                          title: Text(r.peer?.label ?? l10n.riderFallback),
                          subtitle: Text(l10n.wantsToBeFriends),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.accept,
                                onPressed: () async {
                                  await ref
                                      .read(friendshipRepositoryProvider)
                                      .acceptRequest(r.id);
                                  _invalidateSocial();
                                },
                                icon: const Icon(
                                  Icons.check,
                                  color: AppTheme.line,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.decline,
                                onPressed: () async {
                                  await ref
                                      .read(friendshipRepositoryProvider)
                                      .declineRequest(r.id);
                                  _invalidateSocial();
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color: AppTheme.signal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            outgoingAsync.when(
              data: (reqs) {
                if (reqs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.pendingSent,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final r in reqs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(r.peer?.label ?? l10n.riderFallback),
                        subtitle: Text(l10n.waitingAcceptance),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref
                                .read(friendshipRepositoryProvider)
                                .cancelOutgoing(r.id);
                            _invalidateSocial();
                          },
                          child: Text(l10n.cancel),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            Text(
              l10n.yourFriends,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
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
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _invalidateSocial,
                        child: Text(l10n.tryAgain),
                      ),
                    ],
                  ),
                );
              },
              data: (friends) {
                if (friends.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      l10n.noFriendsYet,
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
      _invalidateSocial();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.nameSaved)),
      );
    } catch (e) {
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
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'rides') {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FriendRidesScreen(friend: friend),
                ),
              );
            } else if (v == 'invite') {
              await _inviteToRodada(context, ref);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rides', child: Text(l10n.viewRides)),
            PopupMenuItem(
              value: 'invite',
              child: Text(l10n.inviteToRodada),
            ),
          ],
        ),
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

  Future<void> _inviteToRodada(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final rodadas = await ref.read(myRodadasProvider.future);
    final open = rodadas
        .where((r) => r.status == 'open' || r.status == 'live' || r.status == 'draft')
        .toList();
    if (!context.mounted) return;
    if (open.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createRodadaFirst)),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const RodadasScreen()),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          ListTile(title: Text(l10n.inviteTo)),
          for (final r in open)
            ListTile(
              title: Text(r.title),
              subtitle: Text(r.status),
              onTap: () => Navigator.pop(ctx, r.id),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(rodadaRepositoryProvider).inviteUser(
            rodadaId: picked,
            userId: friend.id,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.friendInvited(friend.label))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
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
                  DateFormat('EEE · MMM d · HH:mm')
                      .format(ride.startedAt.toLocal()),
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${ride.distanceKm.toStringAsFixed(1)} km · '
                  '${formatDuration(ride.duration)} · '
                  '${ride.maxSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
                  style: const TextStyle(color: AppTheme.steel, fontSize: 13),
                ),
                onTap: () {
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
            runSpacing: 8,
            children: [
              Text('${ride.distanceKm.toStringAsFixed(1)} km'),
              Text(formatDuration(ride.duration)),
              Text(
                '${ride.maxSpeedKmh?.toStringAsFixed(0) ?? "—"} ${l10n.kmh}',
              ),
              if (ride.lineScore != null)
                Text(l10n.scoreLabel(ride.lineScore!)),
            ],
          ),
        ],
      ),
    );
  }
}
