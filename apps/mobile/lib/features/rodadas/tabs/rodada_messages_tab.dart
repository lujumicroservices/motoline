import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/push_diagnostics.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../moderation/content_guidelines.dart';
import '../../moderation/content_moderation_repository.dart';
import '../../moderation/report_content_sheet.dart';
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
    final l10n = context.l10n;
    final body = _controller.text.trim();
    if (body.isEmpty && kind == 'text') return;
    if (!await ensureUgcGuidelinesAccepted(context)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(rodadaRepositoryProvider).sendMessage(
            rodadaId: widget.rodadaId,
            body: kind == 'safety'
                ? (body.isEmpty ? l10n.radioNeedHelp : body)
                : body,
            kind: kind,
          );
      _controller.clear();
      ref.invalidate(rodadaMessagesProvider(widget.rodadaId));
      if (kind == 'safety' &&
          PushDiagnostics.hasError &&
          PushDiagnostics.lastLine != null &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.pushDiagnosticsTitle}: ${PushDiagnostics.lastLine}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isUgcBannedError(e) ? l10n.ugcBanned : '$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendCanned(String body) async {
    if (!await ensureUgcGuidelinesAccepted(context)) return;
    if (!mounted) return;
    try {
      await ref.read(rodadaRepositoryProvider).sendMessage(
            rodadaId: widget.rodadaId,
            body: body,
            kind: 'text',
          );
      ref.invalidate(rodadaMessagesProvider(widget.rodadaId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isUgcBannedError(e) ? context.l10n.ugcBanned : '$e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final messages = ref.watch(rodadaMessagesProvider(widget.rodadaId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: Text(l10n.radioAllGood),
                onPressed: _sending ? null : () => _sendCanned(l10n.radioAllGood),
              ),
              ActionChip(
                label: Text(l10n.radioStoppingFiveMin),
                onPressed: _sending
                    ? null
                    : () => _sendCanned(l10n.radioStoppingFiveMin),
              ),
              ActionChip(
                avatar: const Icon(Icons.warning_amber, size: 16),
                label: Text(l10n.radioNeedHelp),
                onPressed: _sending ? null : () => _send(kind: 'safety'),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(rodadaMessagesProvider(widget.rodadaId));
              await ref.read(rodadaMessagesProvider(widget.rodadaId).future);
            },
            child: messages.when(
              loading: () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: CircularProgressIndicator()),
                ],
              ),
              error: (e, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [Text('$e')],
              ),
              data: (list) {
                if (list.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text(l10n.noMessagesYet)),
                    ],
                  );
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  final time =
                      DateFormat('HH:mm').format(m.createdAt.toLocal());
                  final mine = m.userId ==
                      ref.read(rodadaRepositoryProvider).currentUserId;
                  return InkWell(
                    onLongPress: mine
                        ? null
                        : () => showReportContentSheet(
                              context,
                              kind: 'message',
                              messageId: m.id,
                            ),
                    child: Container(
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${m.displayName ?? l10n.riderFallback} · $time'
                                '${m.isSafety ? ' · ${l10n.safetyTag}' : ''}',
                                style: GoogleFonts.exo2(
                                  fontSize: 12,
                                  color: m.isSafety
                                      ? AppTheme.signal
                                      : AppTheme.steel,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (!mine)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.ugcReportTitle,
                                icon: const Icon(Icons.flag_outlined, size: 18),
                                onPressed: () => showReportContentSheet(
                                  context,
                                  kind: 'message',
                                  messageId: m.id,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m.body,
                          style: GoogleFonts.rajdhani(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              );
            },
          ),
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
                    decoration: InputDecoration(
                      hintText: l10n.shortRadioMessageHint,
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
