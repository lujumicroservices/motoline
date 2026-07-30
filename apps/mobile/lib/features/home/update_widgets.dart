import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/app_update_service.dart';
import '../../providers/update_providers.dart';
import '../../theme/app_theme.dart';

class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key, required this.update});

  final AppUpdateInfo update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            'Update available',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CornerIQ ${update.version} is ready '
            '(you have ${update.currentVersion}).',
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
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => showUpdateInstaller(context, ref, update),
                  child: const Text('Update'),
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
    return AlertDialog(
      backgroundColor: AppTheme.asphaltElevated,
      title: Text(
        _error == null ? 'Downloading update' : 'Update failed',
        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
      ),
      content: _error != null
          ? Text(_error!, style: const TextStyle(color: AppTheme.steel))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CornerIQ ${widget.update.version}',
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
                      ? 'Connecting…'
                      : '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: AppTheme.steel),
                ),
              ],
            ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
      ],
    );
  }
}

Future<void> promptManualUpdateCheck(
  BuildContext context,
  WidgetRef ref,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      backgroundColor: AppTheme.asphaltElevated,
      content: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Checking for updates…')),
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
        const SnackBar(content: Text('You’re on the latest CornerIQ.')),
      );
      return;
    }
    ref.invalidate(appUpdateCheckProvider);
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(
          'CornerIQ ${update.version}',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A newer build is available (you have ${update.currentVersion}). '
          'Download and install now?',
          style: const TextStyle(color: AppTheme.steel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (install == true && context.mounted) {
      await showUpdateInstaller(context, ref, update);
    }
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Update check failed: $e')),
    );
  }
}
