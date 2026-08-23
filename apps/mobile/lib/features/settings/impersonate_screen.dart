import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../core/auth/impersonation_controller.dart';

class ImpersonateScreen extends ConsumerStatefulWidget {
  const ImpersonateScreen({super.key});

  @override
  ConsumerState<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends ConsumerState<ImpersonateScreen> {
  final _q = TextEditingController();
  List<ImpersonationHit> _hits = const [];
  bool _searching = false;
  String? _searchError;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 2) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final hits = await ref.read(impersonationProvider.notifier).search(q);
      if (!mounted) return;
      setState(() => _hits = hits);
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchError = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _confirm(ImpersonationHit hit) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.impersonateConfirmTitle),
        content: Text(l10n.impersonateConfirmBody(hit.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.impersonateStart),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final started = await ref.read(impersonationProvider.notifier).start(
          userId: hit.id,
          label: hit.label,
        );
    if (!mounted) return;
    if (!started) {
      final err = ref.read(impersonationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? l10n.impersonateFailed)),
      );
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final st = ref.watch(impersonationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.impersonateTitle,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            l10n.impersonateHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: l10n.impersonateSearchHint,
              suffixIcon: IconButton(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (_searching) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_searchError != null) ...[
            const SizedBox(height: 12),
            Text(
              _searchError!,
              style: GoogleFonts.rajdhani(color: AppTheme.signal),
            ),
          ],
          const SizedBox(height: 12),
          for (final hit in _hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(hit.label),
              subtitle: Text(
                [
                  if (hit.email != null && hit.email!.isNotEmpty) hit.email,
                  hit.id.substring(0, hit.id.length.clamp(0, 8)),
                ].join(' · '),
                style: GoogleFonts.rajdhani(
                  color: AppTheme.steel,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.login),
              onTap: st.busy ? null : () => _confirm(hit),
            ),
          if (!_searching && _hits.isEmpty && _q.text.trim().length >= 2)
            Text(
              l10n.impersonateEmpty,
              style: GoogleFonts.rajdhani(color: AppTheme.steel),
            ),
        ],
      ),
    );
  }
}
