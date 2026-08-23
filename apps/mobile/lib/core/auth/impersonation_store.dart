import 'package:shared_preferences/shared_preferences.dart';

/// Process-wide flag so recorders / FCM can refuse work without Riverpod.
class ImpersonationStore {
  ImpersonationStore._();

  static const activeKey = 'impersonation_active';
  static const adminAccessKey = 'impersonation_admin_access';
  static const adminRefreshKey = 'impersonation_admin_refresh';
  static const targetIdKey = 'impersonation_target_id';
  static const targetLabelKey = 'impersonation_target_label';

  static bool _active = false;
  static String? _targetLabel;
  static String? _targetId;

  static bool get isActive => _active;
  static String? get targetLabel => _targetLabel;
  static String? get targetId => _targetId;

  static Future<void> hydrate() async {
    final p = await SharedPreferences.getInstance();
    _active = p.getBool(activeKey) ?? false;
    _targetLabel = p.getString(targetLabelKey);
    _targetId = p.getString(targetIdKey);
  }

  static Future<void> persistActive({
    required String adminAccessToken,
    required String adminRefreshToken,
    required String targetId,
    required String targetLabel,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(activeKey, true);
    await p.setString(adminAccessKey, adminAccessToken);
    await p.setString(adminRefreshKey, adminRefreshToken);
    await p.setString(targetIdKey, targetId);
    await p.setString(targetLabelKey, targetLabel);
    _active = true;
    _targetId = targetId;
    _targetLabel = targetLabel;
  }

  static Future<({String access, String refresh})?> savedAdminTokens() async {
    final p = await SharedPreferences.getInstance();
    final access = p.getString(adminAccessKey);
    final refresh = p.getString(adminRefreshKey);
    if (access == null ||
        access.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      return null;
    }
    return (access: access, refresh: refresh);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(activeKey);
    await p.remove(adminAccessKey);
    await p.remove(adminRefreshKey);
    await p.remove(targetIdKey);
    await p.remove(targetLabelKey);
    _active = false;
    _targetId = null;
    _targetLabel = null;
  }
}
