import 'package:shared_preferences/shared_preferences.dart';

import 'reel_timeline.dart';

const reelLengthPrefKey = 'reel_length';

Future<ReelLength> loadSavedReelLength() async {
  final prefs = await SharedPreferences.getInstance();
  return ReelLength.fromName(prefs.getString(reelLengthPrefKey));
}

Future<void> saveReelLength(ReelLength length) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(reelLengthPrefKey, length.name);
}
