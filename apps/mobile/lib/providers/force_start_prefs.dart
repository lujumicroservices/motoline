import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const forceStartArmedPrefKey = 'force_start_armed_visible';

class ForceStartArmedVisible extends StateNotifier<bool> {
  ForceStartArmedVisible() : super(!kReleaseMode) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(forceStartArmedPrefKey)) {
      state = prefs.getBool(forceStartArmedPrefKey) ?? state;
    }
  }

  Future<void> setVisible(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(forceStartArmedPrefKey, value);
  }
}

final forceStartArmedVisibleProvider =
    StateNotifierProvider<ForceStartArmedVisible, bool>(
      (ref) => ForceStartArmedVisible(),
    );

/// Armed hub / HUD force-start button. Gated only by the Settings switch.
bool showForceStartArmedButton(bool settingsVisible) => settingsVisible;
