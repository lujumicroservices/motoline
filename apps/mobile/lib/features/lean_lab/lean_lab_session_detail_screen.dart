import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/lean_lab/lean_lab_circuit.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../ride_detail/ride_detail_screen.dart';
import 'lean_lab_review_screen.dart';

/// Revisit a Lean Lab lap: measures, fix config (ida/vuelta…), re-label corners.
class LeanLabSessionDetailScreen extends ConsumerStatefulWidget {
  const LeanLabSessionDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<LeanLabSessionDetailScreen> createState() =>
      _LeanLabSessionDetailScreenState();
}

class _LeanLabSessionDetailScreenState
    extends ConsumerState<LeanLabSessionDetailScreen> {
  LeanLabSession? _session;
  bool _loading = true;
  bool _saving = false;

  late LeanLabSessionType _sessionType;
  late LeanLabDirection _direction;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = await LeanLabService.instance.getSession(widget.rideId);
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _session = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _session = session;
      _sessionType = session.sessionType;
      _direction = session.direction;
      _loading = false;
    });
  }

  bool get _dirty {
    final s = _session;
    if (s == null) return false;
    return _sessionType != s.sessionType ||
        _direction != s.direction;
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final updated = await LeanLabService.instance.updateSessionConfig(
      rideId: widget.rideId,
      sessionType: _sessionType,
      direction: _direction,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (updated != null) _session = updated;
    });
    if (updated != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.leanLabConfigSaved)),
      );
    }
  }

  Future<void> _openReview() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LeanLabReviewScreen(rideId: widget.rideId),
      ),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final session = _session;
    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.leanLabSessionDetailTitle)),
        body: Center(
          child: Text(
            l10n.leanLabSessionMissing,
            style: GoogleFonts.rajdhani(color: AppTheme.steel),
          ),
        ),
      );
    }

    final when = session.createdAt;
    final dateLabel = when == null
        ? '—'
        : DateFormat.yMMMd().add_Hm().format(when.toLocal());
    final corners = [...session.corners]
      ..sort((a, b) => b.appLeanDeg.abs().compareTo(a.appLeanDeg.abs()));

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanLabSessionDetailTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: l10n.leanLabOpenRide,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RideDetailScreen(rideId: widget.rideId),
                ),
              );
            },
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            dateLabel,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            session.needsCornerLabels
                ? l10n.leanLabNeedsLabels
                : l10n.leanLabLabeledCount(session.corners.length),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w700,
              color: session.needsCornerLabels
                  ? AppTheme.lineHot
                  : AppTheme.line,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.leanLabMeasuresTitle,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 8),
          _MeasureGrid(
            items: [
              (
                l10n.leanLabElevationSummary(
                  session.totalClimbM.toStringAsFixed(0),
                  session.totalDescentM.toStringAsFixed(0),
                ),
                l10n.leanLabGrade,
              ),
              (
                '${(session.coveragePct * 100).toStringAsFixed(0)}%',
                l10n.leanLabCoverage,
              ),
              (
                '${session.frozenNeutralDeg.toStringAsFixed(1)}°',
                l10n.leanLabFrozenNeutral,
              ),
              (
                '${session.corners.length}',
                l10n.leanLabCornersCount,
              ),
            ],
          ),
          if (corners.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              l10n.leanLabCornerMeasures,
              style:
                  GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < corners.length; i++)
              _CornerMeasureTile(
                index: i + 1,
                corner: corners[i],
              ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.leanLabEditConfigTitle,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.leanLabEditConfigHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.leanLabProtocols,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in LeanLabSessionType.values.where(
                (t) =>
                    t != LeanLabSessionType.mountPocket ||
                    _sessionType == LeanLabSessionType.mountPocket,
              ))
                ChoiceChip(
                  label: Text(_typeLabel(l10n, t)),
                  selected: _sessionType == t,
                  onSelected: (_) {
                    setState(() {
                      _sessionType = t;
                      final d = LeanLabService.defaultDirection(t);
                      if (d != LeanLabDirection.unknown) {
                        _direction = d;
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.leanLabDirectionQ,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.leanLabDirectionOutbound),
                selected: _direction == LeanLabDirection.outbound,
                onSelected: (_) =>
                    setState(() => _direction = LeanLabDirection.outbound),
              ),
              ChoiceChip(
                label: Text(l10n.leanLabDirectionReturn),
                selected: _direction == LeanLabDirection.returnTrip,
                onSelected: (_) =>
                    setState(() => _direction = LeanLabDirection.returnTrip),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (!_dirty || _saving) ? null : _saveConfig,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l10n.leanLabSaveConfig),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _openReview,
            icon: Icon(
              session.needsCornerLabels
                  ? Icons.label_outline
                  : Icons.replay,
            ),
            label: Text(
              session.needsCornerLabels
                  ? l10n.leanLabReviewTitle
                  : l10n.leanLabRelabelCorners,
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, LeanLabSessionType t) =>
      switch (t) {
        LeanLabSessionType.baselineOutbound => l10n.leanLabProtoOutbound,
        LeanLabSessionType.baselineReturn => l10n.leanLabProtoReturn,
        LeanLabSessionType.mountPocket => l10n.leanLabProtoPocket,
        LeanLabSessionType.free => l10n.leanLabProtoFree,
      };
}

class _MeasureGrid extends StatelessWidget {
  const _MeasureGrid({required this.items});

  final List<(String value, String label)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.asphaltElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: GoogleFonts.exo2(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  item.$2,
                  style: GoogleFonts.rajdhani(
                    color: AppTheme.steel,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CornerMeasureTile extends StatelessWidget {
  const _CornerMeasureTile({
    required this.index,
    required this.corner,
  });

  final int index;
  final LeanLabCornerLabel corner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final side = corner.side == 'left'
        ? l10n.leanLabSideLeft
        : l10n.leanLabSideRight;
    final bias = switch (corner.bias) {
      LeanBiasLabel.appHigh => l10n.leanLabBiasAppHigh,
      LeanBiasLabel.ok => l10n.leanLabBiasOk,
      LeanBiasLabel.appLow => l10n.leanLabBiasAppLow,
      LeanBiasLabel.unsure => l10n.leanLabBiasUnsure,
    };
    final leanColor = RideVizPalette.leanColor(corner.appLeanDeg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Text(
                '#$index',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.steel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${corner.appLeanDeg.abs().toStringAsFixed(0)}° $side',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        color: leanColor,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${l10n.leanLabGrade}: ${corner.avgGradePct.toStringAsFixed(1)}%'
                      ' · $bias',
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.steel,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
