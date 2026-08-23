import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import 'impersonation_controller.dart';

/// Persistent bar while a staff session is swapped onto another rider.
class ImpersonationGate extends ConsumerWidget {
  const ImpersonationGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(impersonationProvider);
    if (!st.active) return child;
    final l10n = context.l10n;
    final name = st.targetLabel ?? l10n.impersonateUnknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF8A1C1C),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.visibility, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.impersonateBanner(name),
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: st.busy
                        ? null
                        : () => ref.read(impersonationProvider.notifier).exit(),
                    child: Text(
                      l10n.impersonateExit,
                      style: GoogleFonts.rajdhani(
                        color: AppTheme.mist,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
