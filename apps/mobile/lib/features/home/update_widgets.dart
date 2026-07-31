import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/app_update_service.dart';
import '../../providers/update_providers.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';

class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key, required this.update});

  final AppUpdateInfo update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.line.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.updateAvailable,
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.updateReady(update.version, update.currentVersion),
            style: const TextStyle(color: AppTheme.steel, fontSize: 13),
          ),
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
          content: Text(
            dialogL10n.updatePrompt(update.currentVersion),
            style: const TextStyle(color: AppTheme.steel),
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
