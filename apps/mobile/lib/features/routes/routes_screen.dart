import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/route_circuit.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/rider_alias_chip.dart';
import 'route_detail_screen.dart';

/// Manage named routes / circuits and share them with friends.
class RoutesScreen extends ConsumerWidget {
  const RoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mineAsync = ref.watch(routesListProvider);
    final peersAsync = ref.watch(sharedPeerRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.routesTitle,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: RiderAliasChip(compact: true)),
          ),
          IconButton(
            tooltip: l10n.createRoute,
            onPressed: () => _showCreateDialog(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(routesListProvider);
          ref.invalidate(sharedPeerRoutesProvider);
          await ref.read(routesListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.asphaltElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.mist.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.routesHowTitle,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.routesHowBody,
                    style: GoogleFonts.outfit(
                      color: AppTheme.steel,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.myRoutes,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            mineAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('$e'),
              data: (routes) {
                if (routes.isEmpty) {
                  return Text(
                    l10n.routesEmpty,
                    style: const TextStyle(color: AppTheme.steel),
                  );
                }
                return Column(
                  children: [
                    for (final route in routes)
                      _MyRouteTile(route: route),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text(
              l10n.friendRoutes,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            peersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => Text(
                l10n.cloudUnavailable,
                style: const TextStyle(color: AppTheme.steel),
              ),
              data: (routes) {
                if (routes.isEmpty) {
                  return Text(
                    l10n.friendRoutesEmpty,
                    style: const TextStyle(color: AppTheme.steel),
                  );
                }
                return Column(
                  children: [
                    for (final r in routes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.route, color: AppTheme.line),
                        title: Text(
                          r.name,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          r.description?.isNotEmpty == true
                              ? r.description!
                              : l10n.sharedRoute,
                          style: const TextStyle(
                            color: AppTheme.steel,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.createRoute),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var shared = true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              backgroundColor: AppTheme.asphaltElevated,
              title: Text(
                l10n.createRoute,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(hintText: l10n.routeNameHint),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(hintText: l10n.routeDescHint),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.shareRoute),
                    subtitle: Text(
                      l10n.shareRouteHelp,
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: shared,
                    onChanged: (v) => setLocal(() => shared = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.notNow),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.saveName),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !context.mounted) return;
    try {
      await ref.read(routeServiceProvider).createRoute(
            name: nameCtrl.text,
            description: descCtrl.text,
            isShared: shared,
          );
      ref.invalidate(routesListProvider);
      ref.invalidate(sharedPeerRoutesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.routeCreated)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _MyRouteTile extends ConsumerWidget {
  const _MyRouteTile({required this.route});

  final RouteCircuit route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      color: AppTheme.asphaltElevated,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RouteDetailScreen(route: route),
            ),
          );
        },
        title: Row(
          children: [
            Expanded(
              child: Text(
                route.name,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
              ),
            ),
            if (route.isLoopReady)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.all_inclusive, size: 16, color: AppTheme.line),
              ),
          ],
        ),
        subtitle: Text(
          [
            if (route.isLoopReady) l10n.routesLoopReady,
            route.isShared ? l10n.sharedRoute : l10n.privateRoute,
            l10n.routesTapHint,
          ].join(' · '),
          style: const TextStyle(color: AppTheme.steel, fontSize: 12),
        ),
        trailing: Switch(
          value: route.isShared,
          onChanged: (v) async {
            await ref.read(routeServiceProvider).setShared(route.id, v);
            ref.invalidate(routesListProvider);
          },
        ),
      ),
    );
  }
}
