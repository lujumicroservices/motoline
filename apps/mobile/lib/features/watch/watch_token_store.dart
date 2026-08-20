import 'package:shared_preferences/shared_preferences.dart';

/// Local cache of the raw magic-link token (DB only stores the hash).
class WatchTokenStore {
  static const _prefix = 'watch_share_raw_v1_';

  Future<void> save(String sessionId, String rawToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$sessionId', rawToken);
  }

  Future<String?> load(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$sessionId');
  }

  Future<void> clear(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$sessionId');
  }
}
