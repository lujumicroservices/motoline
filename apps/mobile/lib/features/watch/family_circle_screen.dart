import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/cloud_models.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/social_providers.dart';
import '../../theme/app_theme.dart';
import 'watch_providers.dart';
import 'watch_viewer_screen.dart';

/// Trusted circle + in-app watch list for family/friends.
class FamilyCircleScreen extends ConsumerWidget {
  const FamilyCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contacts = ref.watch(trustedContactsProvider);
    final watching = ref.watch(visibleWatchSessionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.familyCircleTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(l10n.familyAddContact),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trustedContactsProvider);
          ref.invalidate(visibleWatchSessionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text(
              l10n.familyCircleHelp,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.familyWatchingNow,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            watching.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    l10n.familyNoActiveWatches,
                    style: const TextStyle(color: AppTheme.steel),
                  );
                }
                return Column(
                  children: [
                    for (final s in list)
                      Card(
                        color: AppTheme.asphaltElevated,
                        child: ListTile(
                          leading: const Icon(Icons.sensors, color: AppTheme.line),
                          title: Text(s.riderDisplayName ?? l10n.familyRiderFallback),
                          subtitle: Text(l10n.familyTapToWatch),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WatchViewerScreen(session: s),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              l10n.familyMyCircle,
              style: GoogleFonts.exo2(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            contacts.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Text(
                    l10n.familyCircleEmpty,
                    style: const TextStyle(color: AppTheme.steel),
                  );
                }
                return Column(
                  children: [
                    for (final c in list)
                      Card(
                        color: AppTheme.asphaltElevated,
                        child: ListTile(
                          leading: Icon(
                            c.contactUserId == null
                                ? Icons.link
                                : Icons.favorite,
                            color: AppTheme.lineHot,
                          ),
                          title: Text(c.displayLabel),
                          subtitle: Text(
                            c.contactUserId == null
                                ? l10n.familyLinkOnlyContact
                                : l10n.familyAppContact,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(watchRepositoryProvider)
                                  .revokeContact(c.id);
                              ref.invalidate(trustedContactsProvider);
                            },
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
    );
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final friends = await ref.read(friendsListProvider.future);
    if (!context.mounted) return;

    final labelCtrl = TextEditingController();
    RiderProfile? picked;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(l10n.familyAddContact),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.familyContactLabel,
                        hintText: l10n.familyContactLabelHint,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.familyOptionalFriend,
                        style: const TextStyle(fontSize: 12, color: AppTheme.steel),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (friends.isEmpty)
                      Text(l10n.familyNoFriendsYet)
                    else
                      ...friends.map(
                        (f) => ListTile(
                          dense: true,
                          selected: picked?.id == f.id,
                          title: Text(f.displayName ?? f.id.substring(0, 8)),
                          trailing: picked?.id == f.id
                              ? const Icon(Icons.check, color: AppTheme.line)
                              : null,
                          onTap: () => setLocal(() {
                            picked = picked?.id == f.id ? null : f;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                  FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.familySaveContact),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok != true || !context.mounted) return;
    final label = labelCtrl.text.trim().isEmpty
        ? (picked?.displayName ?? 'Family')
        : labelCtrl.text.trim();
    try {
      final repo = ref.read(watchRepositoryProvider);
      if (picked != null) {
        await repo.addFriendContact(
          friendUserId: picked!.id,
          label: label,
        );
      } else {
        await repo.addLabelContact(label);
      }
      ref.invalidate(trustedContactsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
