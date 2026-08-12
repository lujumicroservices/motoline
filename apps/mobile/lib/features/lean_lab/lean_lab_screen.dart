import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/lean_lab/lean_lab_circuit.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import 'lean_lab_prep_screen.dart';
import 'lean_lab_session_detail_screen.dart';

/// Home for the 3-pilot Lean Lab protocol (Bugambilias + elevation).
class LeanLabScreen extends ConsumerStatefulWidget {
  const LeanLabScreen({super.key});

  @override
  ConsumerState<LeanLabScreen> createState() => _LeanLabScreenState();
}

class _LeanLabScreenState extends ConsumerState<LeanLabScreen> {
  List<LeanLabSession> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    // Restore Garage tracks + Lean Lab metadata for this signed-in account.
    try {
      await ref.read(rideSyncServiceProvider).pullMyCloudRides();
    } catch (_) {}
    try {
      await LeanLabService.instance.pullMyCloudSessions();
    } catch (_) {}
    final list = await LeanLabService.instance.listSessions();
    if (!mounted) return;
    setState(() {
      _sessions = list;
      _loading = false;
    });
    ref.invalidate(ridesListProvider);
  }

  Future<void> _openMap() async {
    final uri = Uri.parse(BugambiliasCircuit.mapsUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _start(LeanLabSessionType type) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeanLabPrepScreen(sessionType: type),
      ),
    );
    if (mounted) unawaited(_reload());
  }

  Future<void> _openSession(LeanLabSession s) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeanLabSessionDetailScreen(rideId: s.rideId),
      ),
    );
    if (mounted) unawaited(_reload());
  }

  String _directionLabel(AppLocalizations l10n, LeanLabDirection d) =>
      switch (d) {
        LeanLabDirection.outbound => l10n.leanLabDirectionOutbound,
        LeanLabDirection.returnTrip => l10n.leanLabDirectionReturn,
        LeanLabDirection.unknown => '—',
      };

  String _typeLabel(AppLocalizations l10n, LeanLabSessionType t) =>
      switch (t) {
        LeanLabSessionType.baselineOutbound => l10n.leanLabProtoOutbound,
        LeanLabSessionType.baselineReturn => l10n.leanLabProtoReturn,
        LeanLabSessionType.mountPocket => l10n.leanLabProtoPocket,
        LeanLabSessionType.free => l10n.leanLabProtoFree,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labeled = _sessions.where((s) => s.corners.isNotEmpty).length;
    final pending = _sessions.where((s) => s.needsCornerLabels).toList();

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanLabTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            l10n.leanLabIntro,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppTheme.asphaltElevated,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _openMap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: AppTheme.line),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.leanLabCircuitName,
                            style: GoogleFonts.exo2(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            l10n.leanLabCircuitHelp,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18, color: AppTheme.steel),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.leanLabProgress(labeled, _sessions.length),
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.leanLabProtocols,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _ProtocolCard(
            title: l10n.leanLabProtoOutbound,
            subtitle: l10n.leanLabProtoOutboundHelp,
            onStart: () => _start(LeanLabSessionType.baselineOutbound),
          ),
          _ProtocolCard(
            title: l10n.leanLabProtoReturn,
            subtitle: l10n.leanLabProtoReturnHelp,
            onStart: () => _start(LeanLabSessionType.baselineReturn),
          ),
          _ProtocolCard(
            title: l10n.leanLabProtoPocket,
            subtitle: l10n.leanLabProtoPocketHelp,
            onStart: () => _start(LeanLabSessionType.mountPocket),
          ),
          _ProtocolCard(
            title: l10n.leanLabProtoFree,
            subtitle: l10n.leanLabProtoFreeHelp,
            onStart: () => _start(LeanLabSessionType.free),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.leanLabNeedsLabels,
                style:
                    GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              for (final s in pending.take(8))
                _SessionTile(
                  session: s,
                  title: _typeLabel(l10n, s.sessionType),
                  direction: _directionLabel(l10n, s.direction),
                  badgeColor: AppTheme.lineHot,
                  badgeIcon: Icons.label_outline,
                  onTap: () => _openSession(s),
                ),
            ],
            if (_sessions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                l10n.leanLabPastSessions,
                style:
                    GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              for (final s in _sessions.take(20))
                _SessionTile(
                  session: s,
                  title: _typeLabel(l10n, s.sessionType),
                  direction: _directionLabel(l10n, s.direction),
                  badgeColor: s.needsCornerLabels
                      ? AppTheme.lineHot
                      : AppTheme.line,
                  badgeIcon: s.needsCornerLabels
                      ? Icons.label_outline
                      : Icons.check_circle_outline,
                  onTap: () => _openSession(s),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.title,
    required this.direction,
    required this.badgeColor,
    required this.badgeIcon,
    required this.onTap,
  });

  final LeanLabSession session;
  final String title;
  final String direction;
  final Color badgeColor;
  final IconData badgeIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final when = session.createdAt;
    final date = when == null
        ? ''
        : DateFormat.MMMd().add_Hm().format(when.toLocal());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(badgeIcon, color: badgeColor),
      title: Text(
        '$title · $direction',
        style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (date.isNotEmpty) date,
          l10n.leanLabElevationSummary(
            session.totalClimbM.toStringAsFixed(0),
            session.totalDescentM.toStringAsFixed(0),
          ),
          if (session.corners.isNotEmpty)
            l10n.leanLabLabeledCount(session.corners.length),
        ].join(' · '),
        style: GoogleFonts.rajdhani(
          color: AppTheme.steel,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({
    required this.title,
    required this.subtitle,
    required this.onStart,
  });

  final String title;
  final String subtitle;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.leanLabStartProtocol),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
