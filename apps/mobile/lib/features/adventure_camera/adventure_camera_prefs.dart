import 'package:shared_preferences/shared_preferences.dart';

/// Persisted toggles for the experimental adventure-camera lab.
///
/// Independent from core ride prefs (auto-pause, etc.).
class AdventureCameraPrefs {
  AdventureCameraPrefs._();

  static const labEnabledKey = 'lab_adventure_camera_enabled';
  static const syncWithRideKey = 'lab_adventure_camera_sync_ride';
  static const syncPauseKey = 'lab_adventure_camera_sync_pause';
  static const backendKey = 'lab_adventure_camera_backend';
  static const lastDeviceIdKey = 'lab_adventure_camera_device_id';

  /// `gopro` | `simulated`
  static const backendGoPro = 'gopro';
  static const backendSimulated = 'simulated';

  static Future<bool> isLabEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(labEnabledKey) ?? false;
  }

  static Future<void> setLabEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(labEnabledKey, value);
  }

  static Future<bool> syncWithRide() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(syncWithRideKey) ?? true;
  }

  static Future<void> setSyncWithRide(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(syncWithRideKey, value);
  }

  static Future<bool> syncPause() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(syncPauseKey) ?? false;
  }

  static Future<void> setSyncPause(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(syncPauseKey, value);
  }

  static Future<String> backend() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(backendKey) ?? backendGoPro;
  }

  static Future<void> setBackend(String value) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(backendKey, value);
  }

  static Future<String?> lastDeviceId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(lastDeviceIdKey);
  }

  static Future<void> setLastDeviceId(String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await p.remove(lastDeviceIdKey);
    } else {
      await p.setString(lastDeviceIdKey, id);
    }
  }
}
