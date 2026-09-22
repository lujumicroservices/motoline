import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_build_info.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_snack.dart';

/// Shows installed version, distribution channel, and optional build label.
class AppVersionTile extends ConsumerWidget {
  const AppVersionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final infoAsync = ref.watch(appBuildInfoProvider);
    final titleStyle = GoogleFonts.rajdhani(fontWeight: FontWeight.w600);
    final subStyle = GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 12);

    return infoAsync.when(
      loading: () => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline, color: AppTheme.steel),
        title: Text(l10n.appVersionTitle, style: titleStyle),
        subtitle: Text('…', style: subStyle),
      ),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline, color: AppTheme.steel),
        title: Text(l10n.appVersionTitle, style: titleStyle),
        subtitle: Text(l10n.appVersionUnavailable, style: subStyle),
      ),
      data: (info) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          info.isExperimental ? Icons.science_outlined : Icons.info_outline,
          color: info.isExperimental ? AppTheme.lineHot : AppTheme.line,
        ),
        title: Text(l10n.appVersionTitle, style: titleStyle),
        subtitle: SelectableText(info.fullLine, style: subStyle),
        trailing: IconButton(
          tooltip: l10n.appVersionCopy,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: info.fullLine));
            if (!context.mounted) return;
            showAppSnack(context, l10n.appVersionCopied);
          },
        ),
      ),
    );
  }
}
