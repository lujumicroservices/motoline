import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'rodada_providers.dart';

class CreateRodadaScreen extends ConsumerStatefulWidget {
  const CreateRodadaScreen({super.key});

  @override
  ConsumerState<CreateRodadaScreen> createState() => _CreateRodadaScreenState();
}

class _CreateRodadaScreenState extends ConsumerState<CreateRodadaScreen> {
  final _title = TextEditingController();
  final _destination = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _startsAt;
  LatLng? _meetup;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
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

  Future<void> _useMyLocation() async {
    final l10n = context.l10n;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() => _meetup = LatLng(pos.latitude, pos.longitude));
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
      final rodada = await ref.read(rodadaRepositoryProvider).createRodada(
            title: title,
            destination: _destination.text.trim().isEmpty
                ? null
                : _destination.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            meetupLat: _meetup?.latitude,
            meetupLng: _meetup?.longitude,
            startsAt: _startsAt,
          );
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          Row(
            children: [
              Text(
                l10n.meetupPin,
                style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: _useMyLocation,
                child: Text(l10n.useMyGps),
              ),
              if (_meetup != null)
                TextButton(
                  onPressed: () => setState(() => _meetup = null),
                  child: Text(l10n.clearPin),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _meetup ?? const LatLng(20.67, -103.35),
                  initialZoom: _meetup == null ? 10 : 14,
                  onTap: (_, p) => setState(() => _meetup = p),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.motoline.motoline',
                  ),
                  if (_meetup != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _meetup!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.place,
                            color: AppTheme.signal,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.meetupMapHelp,
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 13),
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
