import '../../l10n/app_localizations.dart';
import 'rodada_repository.dart';

String messageForInviteResult(AppLocalizations l10n, RodadaInviteResult r) {
  if (r.alreadyMember) return l10n.inviteAlreadyMember;
  if (r.pushDelivered) return l10n.inviteSent;
  if (r.skipped == 'no_tokens') return l10n.inviteSentNoToken;
  return l10n.inviteSentPushFailed(r.error ?? r.skipped ?? 'error');
}

String? messageForInviteBatch(
  AppLocalizations l10n,
  List<RodadaInviteResult> results,
) {
  if (results.isEmpty) return null;
  var sent = 0;
  var failed = 0;
  String? lastReason;
  for (final r in results) {
    if (r.alreadyMember) continue;
    if (r.pushDelivered) {
      sent++;
      continue;
    }
    failed++;
    lastReason = r.error ?? r.skipped ?? 'error';
  }
  if (failed == 0) {
    return sent == 0 ? null : l10n.invitePushAllOk(sent);
  }
  return l10n.invitePushSummary(sent, failed, lastReason ?? 'error');
}
