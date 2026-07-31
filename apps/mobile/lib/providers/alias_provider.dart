import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'social_providers.dart';

const _aliasKey = 'corneriq_alias';

/// Rider alias shown across the app. Prefers cloud profile, falls back to local.
final riderAliasProvider = StateNotifierProvider<RiderAliasController, String>((ref) {
  final controller = RiderAliasController();
  ref.listen(myProfileProvider, (_, next) {
    next.whenData((profile) {
      final name = profile?.displayName?.trim();
      if (name != null && name.isNotEmpty) {
        controller.setAlias(name, persistLocal: true);
      }
    });
  });
  return controller;
});

class RiderAliasController extends StateNotifier<String> {
  RiderAliasController() : super('') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_aliasKey)?.trim() ?? '';
  }

  Future<void> setAlias(String value, {bool persistLocal = true}) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == state) return;
    state = trimmed;
    if (persistLocal) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_aliasKey, trimmed);
    }
  }
}
