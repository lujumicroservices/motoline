import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _proKey = 'riderlab_pro_unlocked';

/// How many brake events Free can see in full (rest are obfuscated).
const freeBrakePreviewCount = 3;

/// Pro entitlement. Persistable toggle until store billing is wired.
final isProProvider =
    StateNotifierProvider<ProEntitlementController, bool>((ref) {
  return ProEntitlementController();
});

class ProEntitlementController extends StateNotifier<bool> {
  ProEntitlementController() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_proKey) ?? false;
  }

  Future<void> setPro(bool unlocked) async {
    state = unlocked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, unlocked);
  }

  Future<void> toggle() => setPro(!state);
}
