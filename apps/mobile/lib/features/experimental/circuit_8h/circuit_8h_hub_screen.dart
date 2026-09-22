import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_build_info.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_snack.dart';
import 'circuit_8h_cloud.dart';
import 'circuit_8h_markers_screen.dart';
import 'circuit_8h_models.dart';
import 'circuit_8h_pass_view_screen.dart';
import 'circuit_8h_record_screen.dart';
import 'circuit_8h_store.dart';

/// Hub: Circuito 8 horas → recorridos tipo A / B → N pasadas cada uno.
class Circuit8hHubScreen extends ConsumerStatefulWidget {
  const Circuit8hHubScreen({super.key});

  @override
  ConsumerState<Circuit8hHubScreen> createState() => _Circuit8hHubScreenState();
}

class _Circuit8hHubScreenState extends ConsumerState<Circuit8hHubScreen> {
  Circuit8hProject _project = const Circuit8hProject();
  bool _loading = true;
  bool _uploading = false;
  String? _lastUploadAt;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final project = await loadCircuit8hProject();
    final last = await loadCircuit8hLastUploadAt();
    if (!mounted) return;
    setState(() {
      _project = project;
      _lastUploadAt = last;
      _loading = false;
    });
  }

  Future<void> _uploadCloud() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final result = await Circuit8hCloudUpload.upload(project: _project);
      if (!mounted) return;
      setState(() => _lastUploadAt = result.uploadedAt);
      showAppSnack(
        context,
        context.l10n.circuit8hUploadOk(result.passCount),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackError(context, '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openRecord(Circuit8hRouteType type) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => Circuit8hRecordScreen(
          routeType: type,
          passNumber: _project.countFor(type) + 1,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _openMarkers() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Circuit8hMarkersScreen(),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openPass(Circuit8hSession session, int passIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Circuit8hPassViewScreen(
          session: session,
          passIndex: passIndex,
        ),
      ),
    );
  }

  Future<void> _deleteSession(Circuit8hSession session) async {
    final next = _project.withoutSession(session.id);
    await saveCircuit8hProject(next);
    if (!mounted) return;
    setState(() => _project = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final buildAsync = ref.watch(appBuildInfoProvider);
    final aSessions = _project.sessionsFor(Circuit8hRouteType.a);
    final bSessions = _project.sessionsFor(Circuit8hRouteType.b);

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(title: Text(l10n.circuit8hTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                buildAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (info) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      info.fullLine,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.mist,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.circuit8hIntro,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.mist,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.line,
                    foregroundColor: AppTheme.asphalt,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _uploading ? null : _uploadCloud,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _uploading
                        ? l10n.circuit8hUploading
                        : l10n.circuit8hUploadCloud,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_lastUploadAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.circuit8hLastUpload(_lastUploadAt!),
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.mist.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Material(
                  color: AppTheme.asphaltElevated,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppTheme.lineHot,
                    ),
                    title: Text(
                      l10n.circuit8hMarkersOpen,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.mist,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      l10n.circuit8hMarkersSummary(
                        _project.hasStart ? l10n.circuit8hYes : l10n.circuit8hNo,
                        _project.hasFinish
                            ? l10n.circuit8hYes
                            : l10n.circuit8hNo,
                        _project.checkpointCount,
                      ),
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.mist.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppTheme.lineHot,
                    ),
                    onTap: _openMarkers,
                  ),
                ),
                const SizedBox(height: 20),
                _RouteCard(
                  title: l10n.circuit8hRouteA,
                  subtitle: l10n.circuit8hRoutePasses(aSessions.length),
                  accent: AppTheme.lineHot,
                  onRecord: () => _openRecord(Circuit8hRouteType.a),
                  onOpenPass: _openPass,
                  sessions: aSessions,
                  onDelete: _deleteSession,
                  emptyHint: l10n.circuit8hNoPassesYet,
                  recordLabel: l10n.circuit8hRecordPass,
                  deleteLabel: l10n.circuit8hDeletePass,
                  openLabel: l10n.circuit8hOpenPass,
                  passMeta: l10n.circuit8hPassMeta,
                  passTitle: l10n.circuit8hPassTitle,
                ),
                const SizedBox(height: 16),
                _RouteCard(
                  title: l10n.circuit8hRouteB,
                  subtitle: l10n.circuit8hRoutePasses(bSessions.length),
                  accent: AppTheme.line,
                  onRecord: () => _openRecord(Circuit8hRouteType.b),
                  onOpenPass: _openPass,
                  sessions: bSessions,
                  onDelete: _deleteSession,
                  emptyHint: l10n.circuit8hNoPassesYet,
                  recordLabel: l10n.circuit8hRecordPass,
                  deleteLabel: l10n.circuit8hDeletePass,
                  openLabel: l10n.circuit8hOpenPass,
                  passMeta: l10n.circuit8hPassMeta,
                  passTitle: l10n.circuit8hPassTitle,
                ),
              ],
            ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onRecord,
    required this.onOpenPass,
    required this.sessions,
    required this.onDelete,
    required this.emptyHint,
    required this.recordLabel,
    required this.deleteLabel,
    required this.openLabel,
    required this.passMeta,
    required this.passTitle,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onRecord;
  final Future<void> Function(Circuit8hSession session, int passIndex)
      onOpenPass;
  final List<Circuit8hSession> sessions;
  final Future<void> Function(Circuit8hSession) onDelete;
  final String emptyHint;
  final String recordLabel;
  final String deleteLabel;
  final String openLabel;
  final String Function(int points, String duration) passMeta;
  final String Function(int index, String time) passTitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.asphaltElevated,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.mist,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.mist.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.asphalt,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: onRecord,
              icon: const Icon(Icons.radio_button_checked),
              label: Text(
                recordLabel,
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  emptyHint,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.mist.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              )
            else
              for (var i = sessions.length - 1; i >= 0; i--)
                _PassTile(
                  title: passTitle(
                    i + 1,
                    _fmtClock(
                      DateTime.fromMillisecondsSinceEpoch(
                        sessions[i].startedAtMs,
                      ),
                    ),
                  ),
                  meta: [
                    if (sessions[i].edge != null)
                      _edgeLabel(context, sessions[i].edge!),
                    passMeta(
                      sessions[i].pointCount,
                      _fmtDuration(sessions[i].duration),
                    ),
                  ].join(' · '),
                  openLabel: openLabel,
                  deleteLabel: deleteLabel,
                  onOpen: () => onOpenPass(sessions[i], i + 1),
                  onDelete: () => onDelete(sessions[i]),
                ),
          ],
        ),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  static String _fmtClock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _edgeLabel(BuildContext context, Circuit8hTrackEdge edge) {
    final l10n = context.l10n;
    return switch (edge) {
      Circuit8hTrackEdge.inner => l10n.circuit8hEdgeInner,
      Circuit8hTrackEdge.outer => l10n.circuit8hEdgeOuter,
    };
  }
}

class _PassTile extends StatelessWidget {
  const _PassTile({
    required this.title,
    required this.meta,
    required this.openLabel,
    required this.deleteLabel,
    required this.onOpen,
    required this.onDelete,
  });

  final String title;
  final String meta;
  final String openLabel;
  final String deleteLabel;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onOpen,
      leading: const Icon(Icons.map_outlined, color: AppTheme.lineHot),
      title: Text(
        title,
        style: GoogleFonts.rajdhani(
          color: AppTheme.mist,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        meta,
        style: GoogleFonts.rajdhani(
          color: AppTheme.mist.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: openLabel,
            onPressed: onOpen,
            icon: const Icon(Icons.visibility_outlined, size: 20),
          ),
          IconButton(
            tooltip: deleteLabel,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
        ],
      ),
    );
  }
}
