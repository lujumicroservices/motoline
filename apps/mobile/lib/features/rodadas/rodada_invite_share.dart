import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/directions_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_ext.dart';
import 'models/rodada_models.dart';
import 'rodada_providers.dart';

const rodadaInviteRiderNameCap = 8;

/// Google Maps search URL (opens in WhatsApp / Maps / browser).
String googleMapsSearchUrl(double lat, double lng) {
  return 'https://maps.google.com/?q=${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
}

class RodadaInviteRiderPreview {
  const RodadaInviteRiderPreview({
    required this.shown,
    required this.total,
    required this.extra,
  });

  final List<String> shown;
  final int total;
  final int extra;
}

/// Going + maybe, host first. Pending / declined stay off the invite.
RodadaInviteRiderPreview rodadaInviteRiderPreview(
  List<RodadaMember> members, {
  int maxNames = rodadaInviteRiderNameCap,
}) {
  final pool = [
    for (final m in members)
      if (m.rsvp == 'going' || m.rsvp == 'maybe') m,
  ]..sort((a, b) {
      if (a.isHost != b.isHost) return a.isHost ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  final names = [for (final m in pool) m.label];
  final cap = maxNames < 1 ? 1 : maxNames;
  if (names.length <= cap) {
    return RodadaInviteRiderPreview(
      shown: names,
      total: names.length,
      extra: 0,
    );
  }
  return RodadaInviteRiderPreview(
    shown: names.sublist(0, cap),
    total: names.length,
    extra: names.length - cap,
  );
}

String joinRodadaInviteShareLines(Iterable<String?> lines) {
  return [
    for (final line in lines)
      if (line != null && line.trim().isNotEmpty) line.trim(),
  ].join('\n');
}

/// Builds the WhatsApp-ready summary. Does not open the share sheet.
String buildRodadaInviteShareText({
  required AppLocalizations l10n,
  required RodadaSummary rodada,
  required List<RodadaMember> members,
  List<RodadaStop> stops = const [],
  required String whenLabel,
}) {
  final dest = rodada.destination?.trim();
  final notes = rodada.notes?.trim();
  String? routeLine;
  final km = rodada.routeDistanceM;
  final eta = rodada.routeDurationS;
  if (km != null && km > 0 && eta != null) {
    routeLine = l10n.rodadaInviteShareRoute(
      '${formatRouteDistance(km)} · ${formatRouteEta(eta)}',
    );
  }

  RodadaMember? host;
  for (final m in members) {
    if (m.isHost) {
      host = m;
      break;
    }
  }

  final riders = rodadaInviteRiderPreview(members);
  String? ridersLine;
  if (riders.total > 0) {
    final names = riders.shown.join(', ');
    ridersLine = riders.extra > 0
        ? l10n.rodadaInviteShareRidersMore(
            riders.total,
            names,
            riders.extra,
          )
        : l10n.rodadaInviteShareRiders(riders.total, names);
  }

  final stopTitles = [
    for (final s in stops)
      if (s.title.trim().isNotEmpty) s.title.trim(),
  ];

  return joinRodadaInviteShareLines([
    rodada.title,
    l10n.rodadaInviteShareWhen(whenLabel),
    if (dest != null && dest.isNotEmpty) l10n.rodadaInviteShareWhere(dest),
    routeLine,
    if (host != null) l10n.rodadaInviteShareHost(host.label),
    ridersLine,
    if (stopTitles.isNotEmpty)
      l10n.rodadaInviteShareStops(stopTitles.join(', ')),
    if (notes != null && notes.isNotEmpty) l10n.rodadaInviteShareNotes(notes),
    if (rodada.hasMeetup)
      l10n.rodadaInviteShareMeetup(
        googleMapsSearchUrl(rodada.meetupLat!, rodada.meetupLng!),
      ),
    if (rodada.hasFinish)
      l10n.rodadaInviteShareFinish(
        googleMapsSearchUrl(rodada.finishLat!, rodada.finishLng!),
      ),
    l10n.rodadaInviteShareCode(rodada.inviteCode),
    l10n.rodadaInviteShareHow,
  ]);
}

SnackBar rodadaInviteShareSnackBar(
  BuildContext context,
  WidgetRef ref, {
  required String rodadaId,
  RodadaSummary? rodada,
}) {
  final l10n = context.l10n;
  return SnackBar(
    duration: const Duration(seconds: 6),
    content: Text(l10n.rodadaInviteShareHint),
    action: SnackBarAction(
      label: l10n.rodadaInviteShare,
      onPressed: () {
        shareRodadaInviteSummary(
          context,
          ref,
          rodadaId: rodadaId,
          rodada: rodada,
        );
      },
    ),
  );
}

/// Copies the summary and opens the system share sheet (WhatsApp, SMS, …).
Future<void> shareRodadaInviteSummary(
  BuildContext context,
  WidgetRef ref, {
  required String rodadaId,
  RodadaSummary? rodada,
}) async {
  final l10n = context.l10n;
  try {
    final r = rodada ??
        await ref.read(rodadaOverviewProvider(rodadaId).future);
    if (r == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rodadaNotFound)),
      );
      return;
    }
    final members = await ref.read(rodadaMembersProvider(rodadaId).future);
    List<RodadaStop> stops = const [];
    try {
      stops = await ref.read(rodadaStopsProvider(rodadaId).future);
    } catch (_) {}
    if (!context.mounted) return;

    final locale = Localizations.localeOf(context).toString();
    final when = r.startsAt == null
        ? l10n.timeTbd
        : DateFormat('EEE d MMM yyyy · HH:mm', locale)
            .format(r.startsAt!.toLocal());
    final text = buildRodadaInviteShareText(
      l10n: l10n,
      rodada: r,
      members: members,
      stops: stops,
      whenLabel: when,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: l10n.rodadaInviteShareSubject(r.title),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e')),
    );
  }
}
