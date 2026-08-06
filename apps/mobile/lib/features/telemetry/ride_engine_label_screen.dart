import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/analytics/ride_analytics.dart';
import '../../core/telemetry/labels/ride_engine_label.dart';
import '../../core/telemetry/labels/ride_engine_label_service.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/bike_provider.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../ride_detail/ride_detail_screen.dart';

/// Beta post-ride survey — trains lean / curve / brake models.
class RideEngineLabelScreen extends ConsumerStatefulWidget {
  const RideEngineLabelScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideEngineLabelScreen> createState() =>
      _RideEngineLabelScreenState();
}

class _RideEngineLabelScreenState extends ConsumerState<RideEngineLabelScreen> {
  String? _mount;
  String? _lean;
  String? _brake;
  String? _context;
  bool _saving = false;

  Future<void> _finish({required bool skipped}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final service = RideEngineLabelService.instance;
      RideAnalytics? analytics;
      try {
        final ride = await ref.read(rideProvider(widget.rideId).future);
        final points = await ref.read(ridePointsProvider(widget.rideId).future);
        if (ride != null) {
          analytics = RideAnalytics(ride: ride, points: points);
        }
      } catch (_) {}

      if (skipped) {
        await service.skip(widget.rideId);
      } else {
        await service.save(
          RideEngineLabel(
            rideId: widget.rideId,
            phoneMount: _mount ?? PhoneMountId.other,
            leanQuality: _lean,
            brakeFeel: _brake,
            rideContext: _context,
            createdAt: DateTime.now(),
          ),
          analytics: analytics,
          bikeId: ref.read(riderBikeProvider)?.id,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RideDetailScreen(rideId: widget.rideId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
      setState(() => _saving = false);
    }
  }

  bool get _canSave => _mount != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.engineLabelTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _finish(skipped: true),
            child: Text(l10n.engineLabelSkip),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Text(
            l10n.engineLabelIntro,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          _QuestionTitle(l10n.engineLabelMountQ),
          const SizedBox(height: 8),
          _ChoiceWrap(
            value: _mount,
            onChanged: (v) => setState(() => _mount = v),
            options: [
              (PhoneMountId.centerMount, l10n.engineLabelMountCenter),
              (PhoneMountId.leftPocket, l10n.engineLabelMountLeftPocket),
              (PhoneMountId.rightPocket, l10n.engineLabelMountRightPocket),
              (PhoneMountId.other, l10n.engineLabelMountOther),
            ],
          ),
          const SizedBox(height: 22),
          _QuestionTitle(l10n.engineLabelLeanQ),
          const SizedBox(height: 8),
          _ChoiceWrap(
            value: _lean,
            onChanged: (v) => setState(() => _lean = v),
            options: [
              (LeanQualityId.good, l10n.engineLabelLeanGood),
              (LeanQualityId.leftHigh, l10n.engineLabelLeanLeftHigh),
              (LeanQualityId.rightHigh, l10n.engineLabelLeanRightHigh),
              (LeanQualityId.bothOff, l10n.engineLabelLeanBothOff),
              (LeanQualityId.unsure, l10n.engineLabelLeanUnsure),
            ],
          ),
          const SizedBox(height: 22),
          _QuestionTitle(l10n.engineLabelBrakeQ),
          const SizedBox(height: 8),
          _ChoiceWrap(
            value: _brake,
            onChanged: (v) => setState(() => _brake = v),
            options: [
              (BrakeFeelId.good, l10n.engineLabelBrakeGood),
              (BrakeFeelId.tooMany, l10n.engineLabelBrakeTooMany),
              (BrakeFeelId.tooFew, l10n.engineLabelBrakeTooFew),
              (BrakeFeelId.unsure, l10n.engineLabelBrakeUnsure),
            ],
          ),
          const SizedBox(height: 22),
          _QuestionTitle(l10n.engineLabelContextQ),
          const SizedBox(height: 8),
          _ChoiceWrap(
            value: _context,
            onChanged: (v) => setState(() => _context = v),
            options: [
              (RideContextId.street, l10n.engineLabelContextStreet),
              (RideContextId.mountain, l10n.engineLabelContextMountain),
              (RideContextId.track, l10n.engineLabelContextTrack),
              (RideContextId.commute, l10n.engineLabelContextCommute),
              (RideContextId.other, l10n.engineLabelContextOther),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: !_canSave || _saving
                ? null
                : () => _finish(skipped: false),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppTheme.mist,
              foregroundColor: AppTheme.asphalt,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.engineLabelSave),
          ),
        ],
      ),
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  const _QuestionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> options;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == id,
            onSelected: (_) => onChanged(id),
            selectedColor: AppTheme.line.withValues(alpha: 0.28),
            backgroundColor: AppTheme.asphaltElevated,
            labelStyle: GoogleFonts.rajdhani(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.mist,
            ),
          ),
      ],
    );
  }
}
