import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import 'rodada_providers.dart';

/// Non-host leave. Returns true if the membership was deleted.
Future<bool> confirmAndLeaveRodada(
  BuildContext context,
  WidgetRef ref, {
  required String rodadaId,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.leaveRodadaConfirmTitle),
      content: Text(l10n.leaveRodadaConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.leaveRodada),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await ref.read(rodadaRepositoryProvider).leaveRodada(rodadaId);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
    return false;
  }
  ref.invalidate(myRodadasProvider);
  ref.invalidate(rodadaOverviewProvider(rodadaId));
  ref.invalidate(myRodadaMembershipProvider(rodadaId));
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.leaveRodadaDone)),
  );
  return true;
}
