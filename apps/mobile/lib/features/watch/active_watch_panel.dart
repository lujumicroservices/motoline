import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'family_share.dart';
import 'watch_providers.dart';

/// Compact safety panel on active ride / rodada screens.
class ActiveWatchPanel extends ConsumerStatefulWidget {
  const ActiveWatchPanel({
    super.key,
    required this.localRideId,
    this.riderDisplayName,
    this.compact = false,
  });

  final String localRideId;
  final String? riderDisplayName;

  /// Tighter layout for embedding under rodada live map banners.
  final bool compact;

  @override
  ConsumerState<ActiveWatchPanel> createState() => _ActiveWatchPanelState();
}

class _ActiveWatchPanelState extends ConsumerState<ActiveWatchPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activeWatchControllerProvider.notifier)
          .resumeFor(localRideId: widget.localRideId);
    });
  }

  @override
  void didUpdateWidget(covariant ActiveWatchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localRideId != widget.localRideId) {
      ref
          .read(activeWatchControllerProvider.notifier)
          .resumeFor(localRideId: widget.localRideId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(activeWatchControllerProvider);
    final ctrl = ref.read(activeWatchControllerProvider.notifier);
    final mine = session != null && session.localRideId == widget.localRideId
        ? session
        : null;

    if (mine == null) {
      if (widget.compact) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.familyNotifyToggle,
              style: const TextStyle(fontSize: 12),
            ),
            IconButton(
              tooltip: l10n.familyNotifyToggle,
              visualDensity: VisualDensity.compact,
              icon: Icon(_shareIcon(context), size: 20),
              onPressed: () => shareFamilyWatchLink(
                context,
                ref,
                localRideId: widget.localRideId,
                riderDisplayName: widget.riderDisplayName,
              ),
            ),
          ],
        );
      }
      return Card(
        color: AppTheme.asphaltElevated,
        child: ListTile(
          title: Text(
            l10n.familyNotifyToggle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(l10n.familyNotifyHelp),
          trailing: FilledButton.icon(
            onPressed: () => shareFamilyWatchLink(
              context,
              ref,
              localRideId: widget.localRideId,
              riderDisplayName: widget.riderDisplayName,
            ),
            icon: Icon(_shareIcon(context), size: 16),
            label: Text(l10n.familyNotifyStart),
          ),
        ),
      );
    }

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.familyWatchActive,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  await ctrl.end();
                },
                child: Text(l10n.familyWatchStop),
              ),
              IconButton(
                tooltip: l10n.familyNotifyToggle,
                visualDensity: VisualDensity.compact,
                icon: Icon(_shareIcon(context), size: 20),
                onPressed: () => shareFamilyWatchLink(
                  context,
                  ref,
                  localRideId: widget.localRideId,
                  riderDisplayName: widget.riderDisplayName,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
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
            ],
          ),
        ],
      );
    }

    return Card(
      color: AppTheme.asphaltElevated,
      margin: widget.compact
          ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
          : null,
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
            Text(
              l10n.familyShareAgainHint,
              style: const TextStyle(color: AppTheme.steel, fontSize: 12),
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
                FilledButton.icon(
                  onPressed: () => shareFamilyWatchLink(
                    context,
                    ref,
                    localRideId: widget.localRideId,
                    riderDisplayName: widget.riderDisplayName,
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: Text(l10n.familyShareAgain),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.familyRotateLinkTitle),
                        content: Text(l10n.familyRotateLinkBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n.familyRotateLinkConfirm),
                          ),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    await shareFamilyWatchLink(
                      context,
                      ref,
                      localRideId: widget.localRideId,
                      riderDisplayName: widget.riderDisplayName,
                      rotateFirst: true,
                    );
                  },
                  icon: const Icon(Icons.lock_reset, size: 16),
                  label: Text(l10n.familyRotateLink),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _shareIcon(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
      ? Icons.ios_share
      : Icons.share;
}
