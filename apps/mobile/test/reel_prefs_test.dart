import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/reel/reel_prefs.dart';
import 'package:motoline/features/reel/reel_timeline.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saved reel length round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadSavedReelLength(), ReelLength.standard);

    await saveReelLength(ReelLength.short);
    expect(await loadSavedReelLength(), ReelLength.short);

    await saveReelLength(ReelLength.long);
    expect(await loadSavedReelLength(), ReelLength.long);
  });
}
