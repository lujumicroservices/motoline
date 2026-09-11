import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/providers/rodada_share_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('share settings persist independently', () async {
    SharedPreferences.setMockInitialValues({});
    final n = RodadaSharePrefs();
    await n.setShareLive(false);
    expect(n.state.shareLive, isFalse);
    await n.setShareLive(true);
    await n.setAutoArmOnStart(true);
    expect(n.state.shareLive, isTrue);
    expect(n.state.autoArmOnStart, isTrue);
    expect(n.state.shareTrack, isFalse);
  });
}
