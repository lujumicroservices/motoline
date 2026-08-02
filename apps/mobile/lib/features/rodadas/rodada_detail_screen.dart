import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import 'rodada_providers.dart';
import 'tabs/rodada_live_tab.dart';
import 'tabs/rodada_messages_tab.dart';
import 'tabs/rodada_overview_tab.dart';
import 'tabs/rodada_photos_tab.dart';
import 'tabs/rodada_rides_tab.dart';

/// Shell with lazy tabs: switching tabs destroys the previous body so
/// autoDispose providers (live GPS, photos, tracks) release immediately.
class RodadaDetailScreen extends ConsumerStatefulWidget {
  const RodadaDetailScreen({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  ConsumerState<RodadaDetailScreen> createState() => _RodadaDetailScreenState();
}

class _RodadaDetailScreenState extends ConsumerState<RodadaDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      setState(() {});
    });
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
    final overview = ref.watch(rodadaOverviewProvider(widget.rodadaId));
    final membership = ref.watch(myRodadaMembershipProvider(widget.rodadaId));

    return Scaffold(
      appBar: AppBar(
        title: overview.when(
          data: (r) => Text(
            r?.title ?? 'Rodada',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          loading: () => const Text('Rodada'),
          error: (_, __) => const Text('Rodada'),
        ),
        actions: [
          overview.maybeWhen(
            data: (r) {
              if (r == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Copy invite code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: r.inviteCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Code ${r.inviteCode} copied')),
                  );
                },
                icon: const Icon(Icons.copy),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          membership.maybeWhen(
            data: (m) {
              if (m == null || !m.isHost) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: _hostAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'live', child: Text('Mark as LIVE')),
                  PopupMenuItem(value: 'open', child: Text('Mark as open')),
                  PopupMenuItem(value: 'ended', child: Text('End rodada')),
                  PopupMenuItem(value: 'invite', child: Text('Invite friend')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Live'),
            Tab(text: 'Rides'),
            Tab(text: 'Photos'),
            Tab(text: 'Radio'),
          ],
        ),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rodada) {
          if (rodada == null) {
            return const Center(child: Text('Rodada not found'));
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
    final repo = ref.read(rodadaRepositoryProvider);
    try {
      if (action == 'invite') {
        await _inviteFriend();
        return;
      }
      await repo.updateRodada(widget.rodadaId, status: action);
      ref.invalidate(rodadaOverviewProvider(widget.rodadaId));
      ref.invalidate(myRodadasProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status → $action')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _inviteFriend() async {
    if (!SupabaseBootstrap.isReady) return;
    final friends = await ref.read(friendsListProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        if (friends.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No friends to invite yet.'),
          );
        }
        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (_, i) {
            final f = friends[i];
            return ListTile(
              title: Text(f.label),
              onTap: () => Navigator.pop(ctx, f.id),
            );
          },
        );
      },
    );
    if (picked == null) return;
    await ref.read(rodadaRepositoryProvider).inviteUser(
          rodadaId: widget.rodadaId,
          userId: picked,
        );
    ref.invalidate(rodadaMembersProvider(widget.rodadaId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite sent')),
    );
  }
}

class _StatusBanner extends ConsumerWidget {
  const _StatusBanner({required this.rodadaId});

  final String rodadaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'code ${r.inviteCode}',
            ].join(' · '),
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
