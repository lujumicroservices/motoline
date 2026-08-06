import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/lean_neutral.dart';
import '../../core/analytics/ride_analytics.dart';
import '../../core/lean_lab/grade_profile.dart';
import '../../core/lean_lab/lean_lab_models.dart';
import '../../core/lean_lab/lean_lab_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../ride_detail/pilot_line_map.dart';
import '../ride_detail/widgets/map_layer_toggles.dart';
import '../ride_detail/widgets/motorcycle_lean_gauge.dart';

/// Label top corners after a Lean Lab lap (felt vs app + grade context).
class LeanLabReviewScreen extends ConsumerStatefulWidget {
  const LeanLabReviewScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<LeanLabReviewScreen> createState() =>
      _LeanLabReviewScreenState();
}

class _LeanLabReviewScreenState extends ConsumerState<LeanLabReviewScreen> {
  LeanLabSession? _session;
  RideAnalytics? _analytics;
  GradeProfile? _grade;
  final Map<int, LeanBiasLabel> _biasByCorner = {};
  bool _saving = false;
  int _cornerIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final session = await LeanLabService.instance.getSession(widget.rideId);
    final ride = await ref.read(rideProvider(widget.rideId).future);
    final points = await ref.read(ridePointsProvider(widget.rideId).future);
    if (!mounted || ride == null) return;
    final analytics = RideAnalytics(
      ride: ride,
      points: points,
      neutralLeanOverride: session?.frozenNeutralDeg,
    );
    final grade = buildGradeProfile(analytics.samples);
    setState(() {
      _session = session;
      _analytics = analytics;
      _grade = grade;
      for (final c in session?.corners ?? const <LeanLabCornerLabel>[]) {
        // Restore by apex index key.
        _biasByCorner[c.apexIndex] = c.bias;
      }
    });
  }

  List<_CornerCandidate> get _candidates {
    final a = _analytics;
    if (a == null) return const [];
    final corners = [...a.skillSummary.corners]
      ..sort((x, y) {
        final lx = x.analysis.maxLeanDegrees;
        final ly = y.analysis.maxLeanDegrees;
        return ly.compareTo(lx);
      });
    return [
      for (final c in corners.take(5))
        _CornerCandidate(
          label: c.label,
          analysisStart: c.analysis.mapStartIndex,
          analysisEnd: c.analysis.mapEndIndex,
          apexIndex: c.analysis.apexIndex,
          appLean: c.analysis.apexLeanDegrees ?? c.analysis.maxLeanDegrees,
          side: (c.analysis.apexLeanDegrees ?? 0) < 0 ? 'left' : 'right',
        ),
    ];
  }

  Future<void> _save() async {
    final session = _session;
    final analytics = _analytics;
    final grade = _grade;
    if (session == null || analytics == null || grade == null) return;
    setState(() => _saving = true);
    final labels = <LeanLabCornerLabel>[];
    for (final c in _candidates) {
      final bias = _biasByCorner[c.apexIndex] ?? LeanBiasLabel.unsure;
      labels.add(
        LeanLabCornerLabel(
          mapStartIndex: c.analysisStart,
          mapEndIndex: c.analysisEnd,
          apexIndex: c.apexIndex,
          side: c.side,
          appLeanDeg: c.appLean,
          bias: bias,
          avgGradePct: grade.averageGradePct(c.analysisStart, c.analysisEnd),
          deltaAltM: grade.altitudeDelta(c.analysisStart, c.analysisEnd),
          vertTrend: grade.dominantTrend(c.analysisStart, c.analysisEnd),
          confidence: bias == LeanBiasLabel.unsure ? 2 : 4,
        ),
      );
    }
    await LeanLabService.instance.saveCornerLabels(
      rideId: widget.rideId,
      corners: labels,
      analytics: analytics,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final analytics = _analytics;
    final candidates = _candidates;
    final session = _session;

    if (analytics == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (candidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.leanLabReviewTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.leanLabNoCorners,
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(color: AppTheme.steel),
            ),
          ),
        ),
      );
    }

    final i = _cornerIndex.clamp(0, candidates.length - 1);
    final c = candidates[i];
    final grade = _grade;
    final avgGrade =
        grade?.averageGradePct(c.analysisStart, c.analysisEnd) ?? 0;
    final trend =
        grade?.dominantTrend(c.analysisStart, c.analysisEnd) ?? VertTrend.unknown;
    final bias = _biasByCorner[c.apexIndex] ?? LeanBiasLabel.unsure;
    final apex = analytics.samples[c.apexIndex.clamp(0, analytics.samples.length - 1)];
    final lean = relativeLeanDegrees(
      rawLeanDegrees: apex.leanDegrees ?? 0,
      neutralDegrees: session?.frozenNeutralDeg ?? analytics.neutralLeanDegrees,
    );

    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(
          l10n.leanLabReviewTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            l10n.leanLabReviewHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (session != null) ...[
            const SizedBox(height: 8),
            Text(
              '${session.direction.id} · ${session.phoneMount} · '
              '${l10n.leanLabElevationSummary(session.totalClimbM.toStringAsFixed(0), session.totalDescentM.toStringAsFixed(0))}',
              style: GoogleFonts.rajdhani(color: AppTheme.mist, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: i > 0 ? () => setState(() => _cornerIndex--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${i + 1}/${candidates.length} · ${c.label}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: i < candidates.length - 1
                    ? () => setState(() => _cornerIndex++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              child: PilotLineMap(
                points: analytics.samples,
                interactive: false,
                allowZoom: true,
                scrubIndex: c.apexIndex,
                focusStartIndex: c.analysisStart,
                focusEndIndex: c.analysisEnd,
                dimOutsideFocus: true,
                layers: const MapLayerOptions(
                  showSpeedColors: true,
                  showBrakes: false,
                  showRoadKindContrast: false,
                  showLegend: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MotorcycleLeanGauge(
            leanDegrees: lean,
            maxLeftDegrees: 55,
            maxRightDegrees: 55,
            height: 140,
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.leanLabAppLean}: ${c.appLean.abs().toStringAsFixed(0)}° ${c.side}'
            ' · ${l10n.leanLabGrade}: ${avgGrade.toStringAsFixed(1)}%'
            ' · ${_trendLabel(l10n, trend)}',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.leanLabBiasQ,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in LeanBiasLabel.values)
                ChoiceChip(
                  label: Text(_biasLabel(l10n, b)),
                  selected: bias == b,
                  selectedColor: RideVizPalette.leanLeft.withValues(alpha: 0.25),
                  onSelected: (_) =>
                      setState(() => _biasByCorner[c.apexIndex] = b),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l10n.leanLabSaveLabels),
          ),
        ],
      ),
    );
  }

  String _biasLabel(AppLocalizations l10n, LeanBiasLabel b) => switch (b) {
        LeanBiasLabel.appHigh => l10n.leanLabBiasAppHigh,
        LeanBiasLabel.ok => l10n.leanLabBiasOk,
        LeanBiasLabel.appLow => l10n.leanLabBiasAppLow,
        LeanBiasLabel.unsure => l10n.leanLabBiasUnsure,
      };

  String _trendLabel(AppLocalizations l10n, VertTrend t) => switch (t) {
        VertTrend.climbing => l10n.leanLabTrendClimbing,
        VertTrend.descending => l10n.leanLabTrendDescending,
        VertTrend.flat => l10n.leanLabTrendFlat,
        VertTrend.unknown => '—',
      };
}

class _CornerCandidate {
  const _CornerCandidate({
    required this.label,
    required this.analysisStart,
    required this.analysisEnd,
    required this.apexIndex,
    required this.appLean,
    required this.side,
  });

  final String label;
  final int analysisStart;
  final int analysisEnd;
  final int apexIndex;
  final double appLean;
  final String side;
}
