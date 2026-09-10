import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'family_share.dart';
import 'watch_providers.dart';

/// Dedicated family-watch controls. Opened from the HUD heart / rodada live.
class FamilyWatchScreen extends ConsumerStatefulWidget {
  const FamilyWatchScreen({
    super.key,
    required this.localRideId,
    this.riderDisplayName,
  });

  final String localRideId;
  final String? riderDisplayName;

  @override
  ConsumerState<FamilyWatchScreen> createState() => _FamilyWatchScreenState();
}

class _FamilyWatchScreenState extends ConsumerState<FamilyWatchScreen> {
  String? _lastKind;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activeWatchControllerProvider.notifier)
          .resumeFor(localRideId: widget.localRideId);
      unawaited(_loadLastEvent());
    });
  }

  Future<void> _loadLastEvent() async {
    final session = ref.read(activeWatchControllerProvider);
    if (session == null || session.localRideId != widget.localRideId) return;
    try {
      final events = await ref
          .read(watchRepositoryProvider)
          .listEvents(session.id);
      if (!mounted || events.isEmpty) return;
      setState(() => _lastKind = events.first.kind);
    } catch (_) {}
  }

  Future<void> _post(Future<void> Function() action, String kind) async {
    await action();
    if (!mounted) return;
    setState(() => _lastKind = kind);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(activeWatchControllerProvider);
    final mine = session != null && session.localRideId == widget.localRideId
        ? session
        : null;
    final ctrl = ref.read(activeWatchControllerProvider.notifier);
    final lastLabel = switch (_lastKind) {
      'ok' => l10n.familyOk,
      'stopped' => l10n.familyStopped,
      'sos' => l10n.familySos,
      _ => null,
    };

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.familyWatchScreenTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l10n.familyWatchScreenHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.familyNotEmergency,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 24),
          if (mine == null) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => shareFamilyWatchLink(
                context,
                ref,
                localRideId: widget.localRideId,
                riderDisplayName: widget.riderDisplayName,
              ),
              icon: Icon(familyShareIcon(context)),
              label: Text(l10n.familyWatchShareCta),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.favorite, color: AppTheme.lineHot),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.familyWatchActive,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (lastLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.familyLastPing(lastLabel),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.line,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatusAction(
                    icon: Icons.check_circle,
                    color: AppTheme.line,
                    label: l10n.familyOk,
                    onTap: () => _post(ctrl.postOk, 'ok'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusAction(
                    icon: Icons.pause_circle,
                    color: AppTheme.mist,
                    label: l10n.familyStopped,
                    onTap: () => _post(ctrl.postStopped, 'stopped'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusAction(
                    icon: Icons.sos,
                    color: AppTheme.lineHot,
                    label: l10n.familySos,
                    onTap: () => _post(ctrl.postSos, 'sos'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l10n.familyShareAgainHint,
              style: GoogleFonts.rajdhani(
                color: AppTheme.steel,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => shareFamilyWatchLink(
                context,
                ref,
                localRideId: widget.localRideId,
                riderDisplayName: widget.riderDisplayName,
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.familyShareAgain),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => confirmRotateFamilyWatchLink(
                context,
                ref,
                localRideId: widget.localRideId,
                riderDisplayName: widget.riderDisplayName,
              ),
              icon: const Icon(Icons.lock_reset),
              label: Text(l10n.familyRotateLink),
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.signal,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                await ctrl.end();
                if (!mounted) return;
                setState(() => _lastKind = null);
              },
              child: Text(l10n.familyWatchStop),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openFamilyWatchScreen(
  BuildContext context, {
  required String localRideId,
  String? riderDisplayName,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => FamilyWatchScreen(
        localRideId: localRideId,
        riderDisplayName: riderDisplayName,
      ),
    ),
  );
}
