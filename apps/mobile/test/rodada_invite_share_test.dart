import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/rodadas/models/rodada_models.dart';
import 'package:motoline/features/rodadas/rodada_invite_share.dart';
import 'package:motoline/l10n/app_localizations_en.dart';

RodadaMember _member({
  required String id,
  required String name,
  String role = 'rider',
  String rsvp = 'going',
}) {
  return RodadaMember(
    rodadaId: 'r1',
    userId: id,
    role: role,
    rsvp: rsvp,
    shareLive: false,
    shareTrack: false,
    presence: 'offline',
    displayName: name,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  test('googleMapsSearchUrl is a tap-friendly maps link', () {
    expect(
      googleMapsSearchUrl(20.666, -103.35),
      'https://maps.google.com/?q=20.66600,-103.35000',
    );
  });

  test('rider preview lists host first and skips pending/declined', () {
    final preview = rodadaInviteRiderPreview([
      _member(id: 'c', name: 'Cesar'),
      _member(id: 'h', name: 'Host', role: 'host'),
      _member(id: 'p', name: 'Pending', rsvp: 'pending'),
      _member(id: 'd', name: 'Nope', rsvp: 'declined'),
      _member(id: 'm', name: 'Maybe', rsvp: 'maybe'),
    ]);
    expect(preview.shown.first, 'Host');
    expect(preview.shown, containsAll(['Cesar', 'Maybe']));
    expect(preview.shown, isNot(contains('Pending')));
    expect(preview.shown, isNot(contains('Nope')));
    expect(preview.total, 3);
    expect(preview.extra, 0);
  });

  test('rider preview truncates with extra count', () {
    final members = [
      for (var i = 0; i < 12; i++)
        _member(id: '$i', name: 'R$i', role: i == 0 ? 'host' : 'rider'),
    ];
    final preview = rodadaInviteRiderPreview(members, maxNames: 8);
    expect(preview.shown, hasLength(8));
    expect(preview.shown.first, 'R0');
    expect(preview.total, 12);
    expect(preview.extra, 4);
  });

  test('share text includes when, people, code, and maps; skips empty route', () {
    final rodada = RodadaSummary(
      id: 'r1',
      hostId: 'h',
      title: 'Tapalpa breakfast',
      status: 'open',
      inviteCode: 'TAP42A',
      destination: 'Tapalpa',
      notes: 'White helmet',
      meetupLat: 20.4,
      meetupLng: -103.3,
    );
    final text = buildRodadaInviteShareText(
      l10n: l10n,
      rodada: rodada,
      members: [
        _member(id: 'h', name: 'RT DobleU', role: 'host'),
        _member(id: 'j', name: 'Juan'),
      ],
      stops: [
        RodadaStop(
          id: 's1',
          rodadaId: 'r1',
          createdBy: 'h',
          title: 'Gas',
          latitude: 20.5,
          longitude: -103.2,
          createdAt: DateTime.utc(2026, 8, 22),
        ),
      ],
      whenLabel: 'Sat 23 Aug 2026 · 14:00',
    );

    expect(text, contains('Tapalpa breakfast'));
    expect(text, contains('When: Sat 23 Aug 2026 · 14:00'));
    expect(text, contains('Where: Tapalpa'));
    expect(text, isNot(contains('Route:')));
    expect(text, contains('Host: RT DobleU'));
    expect(text, contains('Riders (2): RT DobleU, Juan'));
    expect(text, contains('Stops: Gas'));
    expect(text, contains('Notes: White helmet'));
    expect(text, contains('https://maps.google.com/?q=20.40000,-103.30000'));
    expect(text, contains('TAP42A'));
    expect(text, contains('Join with invite code'));
  });
}
