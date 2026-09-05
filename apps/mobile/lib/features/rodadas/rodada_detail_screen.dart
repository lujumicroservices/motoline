import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/cloud_models.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import 'invite_push_feedback.dart';
import 'leave_rodada.dart';
import 'rodada_invite_share.dart';
import 'rodada_providers.dart';
import 'tabs/rodada_live_tab.dart';
import 'tabs/rodada_messages_tab.dart';
import 'tabs/rodada_overview_tab.dart';
import 'tabs/rodada_photos_tab.dart';
import 'tabs/rodada_rides_tab.dart';

/// Shell with lazy tabs: switching tabs destroys the previous body so
/// autoDispose providers (live GPS, photos, tracks) release immediately.
class RodadaDetailScreen extends ConsumerStatefulWidget {
  const RodadaDetailScreen({
    super.key,
    required this.rodadaId,
    this.initialTab = 0,
    this.promptShareInvite = false,
  });

  final String rodadaId;
  final int initialTab;

  /// After create or join-by-code, nudge to share the invitation summary.
  final bool promptShareInvite;

  @override
  ConsumerState<RodadaDetailScreen> createState() => _RodadaDetailScreenState();
}

class _RodadaDetailScreenState extends ConsumerState<RodadaDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
    });
    if (widget.promptShareInvite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          rodadaInviteShareSnackBar(context, ref, rodadaId: widget.rodadaId),
        );
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Widget _activeTab() {
    switch (_tabs.index) {
      case 1:
        return RodadaLiveTab(rodadaId: widget.rodadaId);
      case 2:
        return RodadaRidesTab(rodadaId: widget.rodadaId);
      case 3:
        return RodadaPhotosTab(rodadaId: widget.rodadaId);
      case 4:
        return RodadaMessagesTab(rodadaId: widget.rodadaId);
      case 0:
      default:
        return RodadaOverviewTab(rodadaId: widget.rodadaId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final overview = ref.watch(rodadaOverviewProvider(widget.rodadaId));
    final membership = ref.watch(myRodadaMembershipProvider(widget.rodadaId));

    return Scaffold(
      appBar: AppBar(
        title: overview.when(
          data: (r) => Text(
            r?.title ?? l10n.rodadaFallback,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          loading: () => Text(l10n.rodadaFallback),
          error: (_, __) => Text(l10n.rodadaFallback),
        ),
        actions: [
          overview.maybeWhen(
            data: (r) {
              if (r == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.rodadaInviteShare,
                    onPressed: () => shareRodadaInviteSummary(
                      context,
                      ref,
                      rodadaId: widget.rodadaId,
                      rodada: r,
                    ),
                    icon: const Icon(Icons.ios_share),
                  ),
                  IconButton(
                    tooltip: l10n.copyInviteCode,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: r.inviteCode),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.inviteCodeCopied(r.inviteCode)),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          membership.maybeWhen(
            data: (m) {
              if (m == null) return const SizedBox.shrink();
              if (m.isHost) {
                return PopupMenuButton<String>(
                  onSelected: _hostAction,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'live', child: Text(l10n.startRodada)),
                    PopupMenuItem(value: 'open', child: Text(l10n.markAsOpen)),
                    PopupMenuItem(value: 'ended', child: Text(l10n.endRodada)),
                    PopupMenuItem(
                      value: 'share',
                      child: Text(l10n.rodadaInviteShare),
                    ),
                    PopupMenuItem(
                      value: 'invite',
                      child: Text(l10n.inviteFriend),
                    ),
                  ],
                );
              }
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'share') {
                    await shareRodadaInviteSummary(
                      context,
                      ref,
                      rodadaId: widget.rodadaId,
                    );
                    return;
                  }
                  if (value != 'leave') return;
                  final left = await confirmAndLeaveRodada(
                    context,
                    ref,
                    rodadaId: widget.rodadaId,
                  );
                  if (!left || !context.mounted) return;
                  Navigator.of(context).pop();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'share',
                    child: Text(l10n.rodadaInviteShare),
                  ),
                  PopupMenuItem(value: 'leave', child: Text(l10n.leaveRodada)),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.rodadaTabOverview),
            Tab(text: l10n.rodadaTabLive),
            Tab(text: l10n.rodadaTabRides),
            Tab(text: l10n.rodadaTabPhotos),
            Tab(text: l10n.rodadaTabRadio),
          ],
        ),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rodada) {
          if (rodada == null) {
            return Center(child: Text(l10n.rodadaNotFound));
          }
          return Column(
            children: [
              _StatusBanner(rodadaId: widget.rodadaId),
              Expanded(
                // Key forces full rebuild/dispose when tab index changes.
                child: KeyedSubtree(
                  key: ValueKey(_tabs.index),
                  child: _activeTab(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _hostAction(String action) async {
    final l10n = context.l10n;
    final repo = ref.read(rodadaRepositoryProvider);
    try {
      if (action == 'invite') {
        await _inviteFriends();
        return;
      }
      if (action == 'share') {
        await shareRodadaInviteSummary(context, ref, rodadaId: widget.rodadaId);
        return;
      }
      if (action == 'live') {
        await repo.startRodada(widget.rodadaId);
      } else {
        await repo.updateRodada(widget.rodadaId, status: action);
      }
      ref.invalidate(rodadaOverviewProvider(widget.rodadaId));
      ref.invalidate(myRodadasProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'live'
                ? l10n.rodadaStartedSnack
                : l10n.rodadaStatusChanged(action),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _inviteFriends() async {
    final l10n = context.l10n;
    if (!SupabaseBootstrap.isReady) return;
    final friends = await ref.read(friendsListProvider.future);
    final members = await ref.read(
      rodadaMembersProvider(widget.rodadaId).future,
    );
    if (!mounted) return;
    final taken = {
      for (final m in members)
        if (m.rsvp != 'pending') m.userId,
    };
    final invitable = friends.where((f) => !taken.contains(f.id)).toList();
    final picked = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        if (invitable.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.noFriendsToInvite),
          );
        }
        final height = MediaQuery.sizeOf(ctx).height * 0.55;
        return SizedBox(
          height: height,
          child: _InviteFriendsSheet(friends: invitable),
        );
      },
    );
    if (picked == null || picked.isEmpty) return;
    final repo = ref.read(rodadaRepositoryProvider);
    final results = [
      for (final id in picked)
        await repo.inviteUser(rodadaId: widget.rodadaId, userId: id),
    ];
    ref.invalidate(rodadaMembersProvider(widget.rodadaId));
    if (!mounted) return;
    final msg = messageForInviteBatch(l10n, results);
    if (msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({required this.friends});

  final List<RiderProfile> friends;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final Set<String> _ids = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.inviteFriend,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final f in widget.friends)
                  CheckboxListTile(
                    value: _ids.contains(f.id),
                    title: Text(f.label),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _ids.add(f.id);
                        } else {
                          _ids.remove(f.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _ids.isEmpty
                    ? null
                    : () => Navigator.pop(context, Set<String>.from(_ids)),
                child: Text(l10n.inviteFriends),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends ConsumerWidget {
  const _StatusBanner({required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(rodadaOverviewProvider(rodadaId));
    return overview.maybeWhen(
      data: (r) {
        if (r == null) return const SizedBox.shrink();
        final when = r.startsAt == null
            ? null
            : DateFormat('EEE d MMM · HH:mm').format(r.startsAt!.toLocal());
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: AppTheme.asphaltElevated,
          child: Text(
            [
              r.status.toUpperCase(),
              if (r.destination != null && r.destination!.isNotEmpty)
                r.destination!,
              if (when != null) when,
              l10n.rodadaCodeBanner(r.inviteCode),
            ].join(' · '),
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
