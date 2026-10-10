import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/services/logger_pairing_service.dart';
import '../../core/services/logger_session_importer.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snack.dart';
import '../settings/settings_group.dart';

/// Pair M5 logger + import session folder from SD / file share.
class LoggerHardwareScreen extends ConsumerStatefulWidget {
  const LoggerHardwareScreen({super.key});

  @override
  ConsumerState<LoggerHardwareScreen> createState() =>
      _LoggerHardwareScreenState();
}

class _LoggerHardwareScreenState extends ConsumerState<LoggerHardwareScreen> {
  final _pair = LoggerPairingService();
  String? _code;
  String? _serialCmd;
  bool _busy = false;

  Future<void> _mint() async {
    setState(() => _busy = true);
    try {
      final code = await _pair.mintPairCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _serialCmd = null;
      });
      showAppSnack(context, 'Código: $code (15 min). Clámalo desde el logger.');
    } catch (e) {
      if (mounted) showAppSnack(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    final ctrl = TextEditingController(text: _code ?? '');
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim pair code'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Código',
            hintText: '8 chars',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await _pair.claimCode(code);
      if (!mounted) return;
      setState(() => _serialCmd = res.serialPairCommand);
      await Clipboard.setData(ClipboardData(text: res.serialPairCommand));
      if (!mounted) return;
      showAppSnack(
        context,
        'PAIR copiado. Pégalo en el monitor USB del Basic.',
      );
    } catch (e) {
      if (mounted) showAppSnack(context, 'Claim error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSession() async {
    final picked = await FilePicker.getDirectoryPath(
      dialogTitle: 'Carpeta sesión logger (manifest + gnss.ndjson)',
    );
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final sync = ref.read(rideSyncServiceProvider);
      final importer = LoggerSessionImporter(sync: sync);
      final ride = await importer.importDirectory(Directory(picked));
      if (!mounted) return;
      showAppSnack(
        context,
        'Importada ${ride.pointCount} pts · ${ride.displayTitle()}',
      );
      ref.invalidate(ridesListProvider);
    } catch (e) {
      if (mounted) showAppSnack(context, 'Import fail: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('M5 Logger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hardware post-rodada: microSD en pista, Wi‑Fi en paddock. '
            'Empareja el Basic con tu cuenta y/o importa una carpeta de sesión.',
            style: GoogleFonts.rajdhani(color: AppTheme.steel, fontSize: 15),
          ),
          const SizedBox(height: 16),
          SettingsGroup(
            title: 'Emparejar',
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _mint,
                icon: const Icon(Icons.qr_code_2),
                label: Text(_busy ? '…' : 'Generar código'),
              ),
              if (_code != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _code!,
                  style: GoogleFonts.exo2(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _claim,
                icon: const Icon(Icons.link),
                label: const Text('Claim código → PAIR serial'),
              ),
              if (_serialCmd != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _serialCmd!,
                  style: GoogleFonts.robotoMono(fontSize: 12),
                ),
              ],
            ],
          ),
          SettingsGroup(
            title: 'Importar sesión',
            help: 'Carpeta con manifest.json + gnss.ndjson (desde la microSD).',
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _importSession,
                icon: const Icon(Icons.folder_open),
                label: const Text('Elegir carpeta sesión'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
