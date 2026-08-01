import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/distribution.dart';
import '../../core/services/app_update_service.dart';
import '../../providers/update_providers.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';

/// Compact header control: shows a NEW badge when a newer release exists.
class UpdateCheckIconButton extends ConsumerWidget {
  const UpdateCheckIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final updateAsync = ref.watch(appUpdateCheckProvider);
    final hasUpdate = updateAsync.asData?.value != null;

    return IconButton(
      tooltip: hasUpdate ? l10n.updateAvailable : l10n.checkUpdates,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
      onPressed: () => promptManualUpdateCheck(context, ref),
      icon: Badge(
        isLabelVisible: hasUpdate,
        backgroundColor: AppTheme.lineHot,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        label: Text(
          l10n.newVersionBadge,
          style: GoogleFonts.exo2(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: AppTheme.asphalt,
            height: 1,
          ),
        ),
        child: Icon(
          hasUpdate
              ? Icons.system_update_alt
              : Icons.system_update_alt_outlined,
          size: 18,
          color: hasUpdate ? AppTheme.lineHot : AppTheme.steel,
        ),
      ),
    );
  }
}

class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key, required this.update});

  final AppUpdateInfo update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notes = _previewNotes(update.releaseNotes);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.lineHot.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lineHot.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.lineHot,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.newVersionBadge,
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.asphalt,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.updateAvailable,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.updateReady(update.version, update.currentVersion),
            style: const TextStyle(color: AppTheme.steel, fontSize: 13),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              l10n.whatsNew,
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppTheme.lineHot,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notes,
              style: const TextStyle(
                color: AppTheme.mist,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(dismissedUpdateTagProvider.notifier).state =
                        update.tagName;
                  },
                  child: Text(l10n.later),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => showUpdateInstaller(context, ref, update),
                  child: Text(l10n.update),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _previewNotes(String raw) {
  final cleaned = raw
      .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
      .replaceAll(RegExp(r'\*\*?'), '')
      .replaceAll('`', '')
      .trim();
  if (cleaned.isEmpty) return '';
  final lines = cleaned
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.toLowerCase().startsWith('## install'))
      .take(5)
      .toList();
  var text = lines.join('\n');
  if (text.length > 320) {
    text = '${text.substring(0, 317).trimRight()}…';
  }
  return text;
}

Future<void> showUpdateInstaller(
  BuildContext context,
  WidgetRef ref,
  AppUpdateInfo update,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _UpdateDownloadDialog(update: update);
    },
  );
}

class _UpdateDownloadDialog extends ConsumerStatefulWidget {
  const _UpdateDownloadDialog({required this.update});

  final AppUpdateInfo update;

  @override
  ConsumerState<_UpdateDownloadDialog> createState() =>
      _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<_UpdateDownloadDialog> {
  double _progress = 0;
  String? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;
    try {
      await ref.read(appUpdateServiceProvider).downloadAndInstall(
            widget.update,
            onProgress: (value) {
              if (!mounted) return;
              setState(() => _progress = value);
            },
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: AppTheme.asphaltElevated,
      title: Text(
        _error == null ? l10n.downloadingUpdate : l10n.updateFailed,
        style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
      ),
      content: _error != null
          ? Text(_error!, style: const TextStyle(color: AppTheme.steel))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RiderLab ${widget.update.version}',
                  style: const TextStyle(color: AppTheme.steel),
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress,
                  color: AppTheme.line,
                  backgroundColor: AppTheme.mist.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 10),
                Text(
                  _progress <= 0
                      ? l10n.connecting
                      : '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppTheme.steel),
                ),
              ],
            ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
      ],
    );
  }
}

Future<void> promptManualUpdateCheck(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = context.l10n;

  if (AppDistribution.isPlayStore) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.playStoreUpdatesOnly)),
    );
    return;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppTheme.asphaltElevated,
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(l10n.checkingUpdates)),
        ],
      ),
    ),
  );

  try {
    final update = await ref.read(appUpdateServiceProvider).checkForUpdate();
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onLatest)),
      );
      return;
    }
    ref.invalidate(appUpdateCheckProvider);
    final notes = _previewNotes(update.releaseNotes);
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dialogL10n = ctx.l10n;
        return AlertDialog(
          backgroundColor: AppTheme.asphaltElevated,
          title: Text(
            'RiderLab ${update.version}',
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dialogL10n.updatePrompt(update.currentVersion),
                  style: const TextStyle(color: AppTheme.steel),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    dialogL10n.whatsNew,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.lineHot,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      color: AppTheme.mist,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(dialogL10n.notNow),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dialogL10n.update),
            ),
          ],
        );
      },
    );
    if (install == true && context.mounted) {
      await showUpdateInstaller(context, ref, update);
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.updateCheckFailed('$e'))),
    );
  }
}
