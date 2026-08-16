import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'watch_providers.dart';

/// Compact safety panel on the active-ride screen.
class ActiveWatchPanel extends ConsumerWidget {
  const ActiveWatchPanel({
    super.key,
    required this.localRideId,
    this.riderDisplayName,
  });

  final String localRideId;
  final String? riderDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = ref.watch(activeWatchControllerProvider);
    final ctrl = ref.read(activeWatchControllerProvider.notifier);

    if (session == null) {
      return Card(
        color: AppTheme.asphaltElevated,
        child: ListTile(
          leading: const Icon(Icons.favorite_border, color: AppTheme.lineHot),
          title: Text(l10n.familyNotifyToggle),
          subtitle: Text(l10n.familyNotifyHelp),
          trailing: FilledButton(
            onPressed: () async {
              try {
                final s = await ctrl.startForRide(
                  localRideId: localRideId,
                  riderDisplayName: riderDisplayName,
                );
                final url = s?.shareUrl;
                if (url != null && context.mounted) {
                  await SharePlus.instance.share(
                    ShareParams(
                      text: l10n.familyShareMessage(url),
                      subject: l10n.familyShareSubject,
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: Text(l10n.familyNotifyStart),
          ),
        ),
      );
    }

    return Card(
      color: AppTheme.asphaltElevated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: AppTheme.lineHot, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.familyWatchActive,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await ctrl.end();
                  },
                  child: Text(l10n.familyWatchStop),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => ctrl.postOk(),
                  child: Text(l10n.familyOk),
                ),
                OutlinedButton(
                  onPressed: () => ctrl.postStopped(),
                  child: Text(l10n.familyStopped),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.lineHot,
                  ),
                  onPressed: () => ctrl.postSos(),
                  child: Text(l10n.familySos),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final url = session.shareUrl ?? await ctrl.rotateLink();
                    if (url == null) return;
                    await Clipboard.setData(ClipboardData(text: url));
                    await SharePlus.instance.share(
                      ShareParams(
                        text: l10n.familyShareMessage(url),
                        subject: l10n.familyShareSubject,
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: Text(l10n.familyShareLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
