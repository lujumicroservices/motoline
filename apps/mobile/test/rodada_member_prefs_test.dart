import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/rodadas/models/rodada_models.dart';

void main() {
  test('member prefs default off when columns are missing', () {
    final m = RodadaMember.fromMap({
      'rodada_id': 'r1',
      'user_id': 'u1',
      'role': 'rider',
      'rsvp': 'going',
      'share_live': false,
      'share_track': false,
      'presence': 'offline',
    });
    expect(m.autoArmOnStart, isFalse);
    expect(m.autoShareFamily, isFalse);
  });

  test('member prefs parse auto-arm and family share', () {
    final m = RodadaMember.fromMap({
      'rodada_id': 'r1',
      'user_id': 'u1',
      'role': 'host',
      'rsvp': 'going',
      'share_live': true,
      'share_track': true,
      'auto_arm_on_start': true,
      'auto_share_family': true,
      'presence': 'riding',
    });
    expect(m.isHost, isTrue);
    expect(m.shareLive, isTrue);
    expect(m.autoArmOnStart, isTrue);
    expect(m.autoShareFamily, isTrue);
  });
}
