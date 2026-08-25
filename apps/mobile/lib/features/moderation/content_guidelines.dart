import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'content_moderation_repository.dart';

Future<bool> ensureUgcGuidelinesAccepted(BuildContext context) async {
  if (await ContentModerationRepository.hasAcceptedGuidelines()) {
    return true;
  }
  if (!context.mounted) return false;
  final ok = await showUgcGuidelinesDialog(context, requireAccept: true);
  return ok == true;
}

Future<bool?> showUgcGuidelinesDialog(
  BuildContext context, {
  bool requireAccept = false,
}) {
  final l10n = context.l10n;
  return showDialog<bool>(
    context: context,
    barrierDismissible: !requireAccept,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(
          l10n.ugcGuidelinesTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            l10n.ugcGuidelinesBody,
            style: GoogleFonts.rajdhani(
              color: AppTheme.mist,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        actions: [
          if (!requireAccept)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.close),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
          FilledButton(
            onPressed: () async {
              if (requireAccept) {
                await ContentModerationRepository.acceptGuidelines();
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text(
              requireAccept ? l10n.ugcGuidelinesAccept : l10n.close,
            ),
          ),
        ],
      );
    },
  );
}
