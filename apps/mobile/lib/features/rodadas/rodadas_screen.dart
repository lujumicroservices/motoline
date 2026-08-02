import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/supabase/supabase_bootstrap.dart';
import '../../theme/app_theme.dart';
import 'create_rodada_screen.dart';
import 'models/rodada_models.dart';
import 'rodada_detail_screen.dart';
import 'rodada_providers.dart';

/// Lightweight list — no live GPS / tracks / photos until a rodada is opened.
class RodadasScreen extends ConsumerWidget {
  const RodadasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRodadasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rodadas',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            onPressed: () => _joinWithCode(context, ref),
            icon: const Icon(Icons.vpn_key_outlined),
          ),
          IconButton(
            tooltip: 'Create rodada',
            onPressed: () async {
              final id = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const CreateRodadaScreen()),
              );
              if (id != null && context.mounted) {
                ref.invalidate(myRodadasProvider);
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RodadaDetailScreen(rodadaId: id),
                  ),
                );
                ref.invalidate(myRodadasProvider);
              }
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: !SupabaseBootstrap.isReady
          ? const Center(child: Text('Sign in to use Rodadas'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myRodadasProvider);
                await ref.read(myRodadasProvider.future);
              },
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load rodadas.\n$e'),
                    ),
                  ],
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 40),
                        Text(
                          'Group rides',
                          style: GoogleFonts.exo2(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a rodada for Tapalpa, Moyahua, or anywhere. '
                          'Invite riders, then share live GPS, tracks, and photos '
                          'only when you opt in.',
                          style: GoogleFonts.rajdhani(
                            color: AppTheme.steel,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () async {
                            final id = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const CreateRodadaScreen(),
                              ),
                            );
                            if (id != null && context.mounted) {
                              ref.invalidate(myRodadasProvider);
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RodadaDetailScreen(rodadaId: id),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create rodada'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _joinWithCode(context, ref),
                          icon: const Icon(Icons.vpn_key_outlined),
                          label: const Text('Join with invite code'),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = items[i];
                      return _RodadaCard(
                        rodada: r,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  RodadaDetailScreen(rodadaId: r.id),
                            ),
                          );
                          ref.invalidate(myRodadasProvider);
                        },
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  Future<void> _joinWithCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join rodada'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            hintText: 'e.g. TAP42A',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      final id =
          await ref.read(rodadaRepositoryProvider).joinByCode(code);
      ref.invalidate(myRodadasProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RodadaDetailScreen(rodadaId: id)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join failed: $e')),
      );
    }
  }
}

class _RodadaCard extends StatelessWidget {
  const _RodadaCard({required this.rodada, required this.onTap});

  final RodadaSummary rodada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = rodada.startsAt;
    final dateLabel = date == null
        ? 'Time TBD'
        : DateFormat('EEE d MMM · HH:mm').format(date.toLocal());
    final statusColor = switch (rodada.status) {
      'live' => AppTheme.line,
      'ended' => AppTheme.steel,
      _ => AppTheme.lineHot,
    };

    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rodada.title,
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (rodada.destination != null &&
                            rodada.destination!.trim().isNotEmpty)
                          rodada.destination!,
                        dateLabel,
                        '${rodada.memberCount} riders',
                      ].join(' · '),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                rodada.status.toUpperCase(),
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
