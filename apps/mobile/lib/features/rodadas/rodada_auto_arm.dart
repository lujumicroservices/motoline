import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rodada_repository.dart';

/// One-shot auto-arm for a live rodada.
///
/// The freeze sheet is offered at most once. After that (accept, swipe-away,
/// or permission deny) the rider arms again with the Home "Start Rolling"
/// button. Turning the switch back on clears this and allows one more shot.
class RodadaAutoArm {
  static const prefsKey = 'rodada_auto_arm_consumed_v1';

  static Future<Set<String>> loadConsumed() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(prefsKey)};
  }

  static Future<bool> isConsumed(String rodadaId) async {
    return (await loadConsumed()).contains(rodadaId);
  }

  static Future<void> markConsumed(String rodadaId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = {...?prefs.getStringList(prefsKey), rodadaId};
    await prefs.setStringList(prefsKey, ids.toList());
  }

  static Future<void> clearConsumed(String rodadaId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = {...?prefs.getStringList(prefsKey)}..remove(rodadaId);
    await prefs.setStringList(prefsKey, ids.toList());
  }

  /// Marks this rodada as already offered. Does not change global Settings.
  static Future<void> consume({
    required String rodadaId,
    RodadaRepository? repository,
  }) async {
    await markConsumed(rodadaId);
    // [repository] kept for call-site compatibility; membership flags
    // now follow global Settings, not a one-shot cloud toggle.
    if (repository == null) return;
  }
}
