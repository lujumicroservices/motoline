import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n_ext.dart';
import '../ride_active/location_permission_gate.dart';
import 'watch_providers.dart';

/// Starts (or reuses) a family watch session and opens the system share sheet.
///
/// Re-sharing uses the **same** URL so earlier recipients keep working.
/// Pass [rotateFirst] only when you intentionally invalidate old links.
Future<void> shareFamilyWatchLink(
  BuildContext context,
  WidgetRef ref, {
  required String localRideId,
  String? riderDisplayName,
  bool rotateFirst = false,
}) async {
  final l10n = context.l10n;
  final ctrl = ref.read(activeWatchControllerProvider.notifier);
  try {
    final gated = await LocationPermissionGate.requestForRodadaLive(context);
    if (!gated || !context.mounted) return;

    var session = ref.read(activeWatchControllerProvider);
    if (session == null || session.localRideId != localRideId) {
      await ctrl.resumeFor(localRideId: localRideId);
      session = ref.read(activeWatchControllerProvider);
    }
    if (session == null) {
      session = await ctrl.startForRide(
        localRideId: localRideId,
        riderDisplayName: riderDisplayName,
      );
    }
    if (session == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.familyShareNeedsSignIn)),
      );
      return;
    }

    final url = rotateFirst
        ? await ctrl.rotateLink()
        : await ctrl.ensureShareUrl();
    if (url == null || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    await SharePlus.instance.share(
      ShareParams(
        text: l10n.familyShareMessage(url),
        subject: l10n.familyShareSubject,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}
