import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../maps/live_gps_map_mixin.dart';
import 'rodada_itinerary.dart';
import 'rodada_itinerary_map.dart';
import 'rodada_providers.dart';

class CreateRodadaScreen extends ConsumerStatefulWidget {
  const CreateRodadaScreen({super.key});

  @override
  ConsumerState<CreateRodadaScreen> createState() => _CreateRodadaScreenState();
}

class _CreateRodadaScreenState extends ConsumerState<CreateRodadaScreen>
    with LiveGpsMapMixin {
  final MapController _map = MapController();
  final _title = TextEditingController();
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _startsAt;
  RodadaPinMode _mode = RodadaPinMode.start;
  LatLng? _start;
  LatLng? _finish;
  final List<DraftRodadaStop> _stops = [];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    stopLiveGps();
    disposeLiveGpsListenable();
    _title.dispose();
    _destination.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStartsAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _place(LatLng point) {
    final l10n = context.l10n;
    setState(() {
      switch (_mode) {
        case RodadaPinMode.start:
          _start = point;
        case RodadaPinMode.finish:
          _finish = point;
        case RodadaPinMode.stop:
          _stops.add(
            DraftRodadaStop(
              point: point,
              title: l10n.rodadaStopN(_stops.length + 1),
            ),
          );
      }
    });
    try {
      _map.move(point, _map.camera.zoom < 14 ? 16 : _map.camera.zoom);
    } catch (_) {}
  }

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      _place(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationFailed('$e'))),
      );
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.titleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(rodadaRepositoryProvider);
      final rodada = await repo.createRodada(
        title: title,
        destination: _destination.text.trim().isEmpty
            ? null
            : _destination.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        meetupLat: _start?.latitude,
        meetupLng: _start?.longitude,
        finishLat: _finish?.latitude,
        finishLng: _finish?.longitude,
        startsAt: _startsAt,
      );
      for (var i = 0; i < _stops.length; i++) {
        final stop = _stops[i];
        await repo.addStop(
          rodadaId: rodada.id,
          title: stop.title,
          latitude: stop.point.latitude,
          longitude: stop.point.longitude,
          sortOrder: i,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(rodada.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  String _modeLabel(AppLocalizations l10n, RodadaPinMode mode) {
    return switch (mode) {
      RodadaPinMode.start => l10n.rodadaPinStart,
      RodadaPinMode.finish => l10n.rodadaPinFinish,
      RodadaPinMode.stop => l10n.rodadaPinStop,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final line = rodadaItineraryLine(
      start: _start,
      stops: [for (final s in _stops) s.point],
      finish: _finish,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.newRodada,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.rodadaCreateButton),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: l10n.rodadaTitleLabel,
              hintText: l10n.rodadaTitleHint,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            decoration: InputDecoration(
              labelText: l10n.rodadaDestinationLabel,
              hintText: l10n.rodadaDestinationHint,
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.rodadaNotesLabel,
              hintText: l10n.rodadaNotesHint,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.rodadaStartsAt),
            subtitle: Text(
              _startsAt == null
                  ? l10n.rodadaPickDateTime
                  : _startsAt!.toLocal().toString().substring(0, 16),
            ),
            trailing: const Icon(Icons.schedule),
            onTap: _pickStartsAt,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rodadaItinerary,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<RodadaPinMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in RodadaPinMode.values)
                ButtonSegment(
                  value: mode,
                  label: Text(_modeLabel(l10n, mode)),
                ),
            ],
            selected: {_mode},
            onSelectionChanged: (set) {
              if (set.isEmpty) return;
              setState(() => _mode = set.first);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: _useMyLocation,
                child: Text(l10n.useMyGps),
              ),
            ],
          ),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: line.isNotEmpty
                          ? line.first
                          : const LatLng(20.67, -103.35),
                      initialZoom: line.isEmpty ? 10 : 14,
                      onTap: (_, p) => _place(p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.motoline.motoline',
                      ),
                      ...rodadaItineraryMapLayers(
                        start: _start,
                        finish: _finish,
                        stops: [
                          for (final s in _stops)
                            RodadaItineraryStopPin(
                              point: s.point,
                              title: s.title,
                            ),
                        ],
                      ),
                      liveGpsMapChild(),
                    ],
                  ),
                  myLocationOverlay(_map),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rodadaItineraryHelp,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _PinRow(
            icon: Icons.flag,
            color: AppTheme.lineHot,
            label: l10n.rodadaPinStart,
            value: _start == null ? l10n.rodadaPinUnset : null,
            onClear: _start == null
                ? null
                : () => setState(() => _start = null),
          ),
          _PinRow(
            icon: Icons.sports_score,
            color: AppTheme.line,
            label: l10n.rodadaPinFinish,
            value: _finish == null ? l10n.rodadaPinUnset : null,
            onClear: _finish == null
                ? null
                : () => setState(() => _finish = null),
          ),
          for (var i = 0; i < _stops.length; i++)
            _PinRow(
              icon: Icons.local_gas_station,
              color: AppTheme.signal,
              label: _stops[i].title,
              onClear: () => setState(() => _stops.removeAt(i)),
            ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.signal)),
          ],
        ],
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.icon,
    required this.color,
    required this.label,
    this.value,
    this.onClear,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String? value;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      subtitle: value == null ? null : Text(value!),
      trailing: onClear == null
          ? null
          : TextButton(
              onPressed: onClear,
              child: Text(l10n.clearPin),
            ),
    );
  }
}
