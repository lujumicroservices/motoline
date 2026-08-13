import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/bikes/bike_catalog.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/bike_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/ride_viz_palette.dart';
import '../home/home_nav_icons.dart';

enum _BikePickStep { make, year, model }

/// Manufacturer → year → model garage picker.
class BikePickerScreen extends ConsumerStatefulWidget {
  const BikePickerScreen({super.key});

  @override
  ConsumerState<BikePickerScreen> createState() => _BikePickerScreenState();
}

class _BikePickerScreenState extends ConsumerState<BikePickerScreen> {
  _BikePickStep _step = _BikePickStep.make;
  String _query = '';
  String? _make;
  int? _year;
  BikeCatalog? _catalog;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    BikeCatalog.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setStep(_BikePickStep step) {
    setState(() {
      _step = step;
      _query = '';
      _search.clear();
    });
  }

  Future<bool> _onWillPop() async {
    if (_step == _BikePickStep.model) {
      _setStep(_BikePickStep.year);
      return false;
    }
    if (_step == _BikePickStep.year) {
      _setStep(_BikePickStep.make);
      return false;
    }
    return true;
  }

  Future<void> _choose(String make, int year, String model) async {
    final catalog = _catalog ?? BikeCatalog.instance;
    final bike = catalog.pick(make, year, model);
    await ref.read(riderBikeProvider.notifier).select(bike);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _customModel() async {
    final l10n = context.l10n;
    final make = _make;
    final year = _year;
    if (make == null || year == null) return;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.asphaltElevated,
        title: Text(l10n.bikeCustomModel, style: GoogleFonts.exo2()),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.exo2(),
          decoration: InputDecoration(hintText: l10n.bikeCustomModelHint),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.bikeStepModel),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _choose(make, year, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = ref.watch(riderBikeProvider);
    final catalog = _catalog;
    final title = switch (_step) {
      _BikePickStep.make => l10n.bikeStepMake,
      _BikePickStep.year => l10n.bikeStepYear,
      _BikePickStep.model => l10n.bikeStepModel,
    };
    final hint = switch (_step) {
      _BikePickStep.make => l10n.bikeSearchMake,
      _BikePickStep.year => l10n.bikeSearchYear,
      _BikePickStep.model => l10n.bikeSearchModel,
    };

    return PopScope(
      canPop: _step == _BikePickStep.make,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.asphalt,
        appBar: AppBar(
          title: Text(
            title,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop() && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: catalog == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(
                    l10n.bikePickerHelp,
                    style: GoogleFonts.rajdhani(
                      color: AppTheme.steel,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  if (_make != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          label: _make!,
                          onTap: () => _setStep(_BikePickStep.make),
                        ),
                        if (_year != null)
                          _Chip(
                            label: '$_year',
                            onTap: () => _setStep(_BikePickStep.year),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.exo2(),
                    keyboardType: _step == _BikePickStep.year
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppTheme.asphaltElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selected != null && _step == _BikePickStep.make)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: AppTheme.line.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          leading: const AppMotoIcon(
                            size: 28,
                            color: RideVizPalette.leanLeft,
                          ),
                          title: Text(
                            selected.label,
                            style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            selected.subtitle,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.steel,
                              fontSize: 12,
                            ),
                          ),
                          trailing: TextButton(
                            onPressed: () =>
                                ref.read(riderBikeProvider.notifier).clear(),
                            child: Text(l10n.bikeClear),
                          ),
                        ),
                      ),
                    ),
                  ..._stepBody(l10n, catalog),
                ],
              ),
      ),
    );
  }

  List<Widget> _stepBody(AppLocalizations l10n, BikeCatalog catalog) {
    switch (_step) {
      case _BikePickStep.make:
        final names = catalog.makeNames(query: _query);
        if (_query.trim().isNotEmpty) {
          return [
            for (final n in names)
              _tile(n, onTap: () {
                setState(() => _make = n);
                _setStep(_BikePickStep.year);
              }),
          ];
        }
        final pinned = [
          for (final p in BikeCatalog.pinnedMakes)
            if (names.any((n) => n.toLowerCase() == p.toLowerCase())) p,
        ];
        final rest = [
          for (final n in names)
            if (!pinned.any((p) => p.toLowerCase() == n.toLowerCase())) n,
        ];
        return [
          if (pinned.isNotEmpty && _query.trim().isEmpty) ...[
            _Header(l10n.bikePopularMakes),
            for (final n in pinned) _tile(n, onTap: () {
              setState(() => _make = n);
              _setStep(_BikePickStep.year);
            }),
            const SizedBox(height: 8),
            _Header(l10n.bikeAllMakes),
          ],
          for (final n in rest)
            _tile(n, onTap: () {
              setState(() => _make = n);
              _setStep(_BikePickStep.year);
            }),
        ];
      case _BikePickStep.year:
        final years = catalog.yearsFor(_make ?? '', query: _query);
        return [
          for (final y in years)
            _tile('$y', onTap: () {
              setState(() => _year = y);
              _setStep(_BikePickStep.model);
            }),
        ];
      case _BikePickStep.model:
        final models = catalog.modelsFor(
          _make ?? '',
          _year ?? BikeCatalog.yearMax,
          query: _query,
        );
        return [
          for (final n in models)
            _tile(n, onTap: () => _choose(_make!, _year!, n)),
          const SizedBox(height: 8),
          _tile(
            l10n.bikeCustomModel,
            onTap: _customModel,
            muted: true,
          ),
        ];
    }
  }

  Widget _tile(String label, {required VoidCallback onTap, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.asphaltElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w600,
                      color: muted ? AppTheme.steel : AppTheme.mist,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.steel, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppTheme.mist,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: GoogleFonts.exo2(fontWeight: FontWeight.w600)),
      onPressed: onTap,
      backgroundColor: AppTheme.asphaltElevated,
      side: const BorderSide(color: AppTheme.line),
    );
  }
}
