import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../rodada_providers.dart';

/// Short radio / safety pings — tiny payloads, no media.
class RodadaMessagesTab extends ConsumerStatefulWidget {
  const RodadaMessagesTab({super.key, required this.rodadaId});

  final String rodadaId;

  @override
  ConsumerState<RodadaMessagesTab> createState() => _RodadaMessagesTabState();
}

class _RodadaMessagesTabState extends ConsumerState<RodadaMessagesTab> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send({String kind = 'text'}) async {
    final body = _controller.text.trim();
    if (body.isEmpty && kind == 'text') return;
    setState(() => _sending = true);
    try {
      await ref.read(rodadaRepositoryProvider).sendMessage(
            rodadaId: widget.rodadaId,
            body: kind == 'safety' ? (body.isEmpty ? 'Need help' : body) : body,
            kind: kind,
          );
      _controller.clear();
      ref.invalidate(rodadaMessagesProvider(widget.rodadaId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(rodadaMessagesProvider(widget.rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('All good'),
                onPressed: _sending
                    ? null
                    : () async {
                        await ref.read(rodadaRepositoryProvider).sendMessage(
                              rodadaId: widget.rodadaId,
                              body: 'All good',
                              kind: 'text',
                            );
                        ref.invalidate(
                          rodadaMessagesProvider(widget.rodadaId),
                        );
                      },
              ),
              ActionChip(
                label: const Text('Stopping 5 min'),
                onPressed: _sending
                    ? null
                    : () async {
                        await ref.read(rodadaRepositoryProvider).sendMessage(
                              rodadaId: widget.rodadaId,
                              body: 'Stopping 5 min',
                              kind: 'text',
                            );
                        ref.invalidate(
                          rodadaMessagesProvider(widget.rodadaId),
                        );
                      },
              ),
              ActionChip(
                avatar: const Icon(Icons.warning_amber, size: 16),
                label: const Text('Need help'),
                onPressed: _sending ? null : () => _send(kind: 'safety'),
              ),
            ],
          ),
        ),
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No messages yet'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final time =
                      DateFormat('HH:mm').format(m.createdAt.toLocal());
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.isSafety
                          ? AppTheme.signal.withValues(alpha: 0.15)
                          : AppTheme.asphaltElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m.displayName ?? 'Rider'} · $time'
                          '${m.isSafety ? ' · SAFETY' : ''}',
                          style: GoogleFonts.exo2(
                            fontSize: 12,
                            color: m.isSafety ? AppTheme.signal : AppTheme.steel,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.body,
                          style: GoogleFonts.rajdhani(fontSize: 15),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Short radio message…',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
