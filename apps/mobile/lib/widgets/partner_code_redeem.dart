import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/pro/pro_entitlement.dart';
import '../l10n/l10n_ext.dart';
import '../providers/pro_entitlement_provider.dart';
import '../theme/app_theme.dart';

String partnerCodeErrorMessage(AppLocalizations l10n, String? error) {
  switch (error) {
    case 'code_used':
      return l10n.partnerCodeUsed;
    case 'already_redeemed_partner':
      return l10n.partnerCodeAlreadyRedeemed;
    case 'already_paying':
      return l10n.partnerCodeAlreadyPaying;
    case 'invalid_code':
    default:
      return l10n.partnerCodeInvalid;
  }
}

String? proRemainingLabel(AppLocalizations l10n, ProEntitlementStatus status) {
  if (!status.isPro || status.daysLeft <= 0) return null;
  if (status.isTrial) return l10n.proTrialDaysLeft(status.daysLeft);
  if (status.isPartner) return l10n.proPartnerDaysLeft(status.daysLeft);
  return null;
}

class PartnerCodeRedeemField extends ConsumerStatefulWidget {
  const PartnerCodeRedeemField({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<PartnerCodeRedeemField> createState() =>
      _PartnerCodeRedeemFieldState();
}

class _PartnerCodeRedeemFieldState
    extends ConsumerState<PartnerCodeRedeemField> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result =
        await ref.read(proEntitlementProvider.notifier).redeemPartnerCode(
              _controller.text,
            );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.partnerCodeRedeemed)),
      );
    } else {
      setState(() => _error = partnerCodeErrorMessage(l10n, result.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(proEntitlementProvider);
    if (status.partnerUsed || status.isPaid) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            l10n.partnerProCode,
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.partnerProCodeHelp,
            style: GoogleFonts.rajdhani(
              color: AppTheme.steel,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: l10n.partnerProCodeHint,
                  errorText: _error,
                  isDense: true,
                ),
                onSubmitted: (_) => _redeem(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _redeem,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.redeemPartnerCode),
            ),
          ],
        ),
      ],
    );
  }
}
