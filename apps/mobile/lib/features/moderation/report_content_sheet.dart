import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'content_moderation_providers.dart';
import 'content_moderation_repository.dart';

const ugcReportReasons = ['sexual', 'hate', 'harassment', 'spam', 'other'];

Future<void> showReportContentSheet(
  BuildContext context, {
  required String kind,
  String? messageId,
  String? photoId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _ReportSheet(
      kind: kind,
      messageId: messageId,
      photoId: photoId,
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.kind,
    this.messageId,
    this.photoId,
  });

  final String kind;
  final String? messageId;
  final String? photoId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  String _reason = 'other';
  bool _busy = false;

  String _label(AppLocalizations l10n, String reason) => switch (reason) {
        'sexual' => l10n.ugcReasonSexual,
        'hate' => l10n.ugcReasonHate,
        'harassment' => l10n.ugcReasonHarassment,
        'spam' => l10n.ugcReasonSpam,
        _ => l10n.ugcReasonOther,
      };

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(contentModerationRepositoryProvider).report(
            kind: widget.kind,
            messageId: widget.messageId,
            photoId: widget.photoId,
            reason: _reason,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ugcReportThanks)),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = isUgcBannedError(e) ? l10n.ugcBanned : '$e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.ugcReportTitle,
              style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.ugcReportHelp,
              style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final r in ugcReportReasons)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: r,
                groupValue: _reason,
                title: Text( _label(l10n, r)),
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => _reason = v);
                      },
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(l10n.ugcReportSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
