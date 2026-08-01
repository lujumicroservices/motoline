import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/camera_member.dart';
import 'models/camera_zone.dart';

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
  static const zonesEnabledKey = 'lab_adventure_camera_zones_enabled';
  static const zonesJsonKey = 'lab_adventure_camera_zones_json';
  static const aggressiveEnabledKey = 'lab_adventure_camera_aggressive';
  static const cameraGroupJsonKey = 'lab_adventure_camera_group_json';

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

  static Future<bool> zonesEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(zonesEnabledKey) ?? false;
  }

  static Future<void> setZonesEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(zonesEnabledKey, value);
  }

  static Future<List<CameraZone>> zones() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(zonesJsonKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) CameraZone.fromJson(item)
          else if (item is Map)
            CameraZone.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setZones(List<CameraZone> zones) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      zonesJsonKey,
      jsonEncode([for (final z in zones) z.toJson()]),
    );
  }

  static Future<bool> aggressiveEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(aggressiveEnabledKey) ?? false;
  }

  static Future<void> setAggressiveEnabled(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(aggressiveEnabledKey, value);
  }

  static Future<List<CameraMember>> cameraGroup() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(cameraGroupJsonKey);
    if (raw == null || raw.isEmpty) {
      // Migrate single last-device into a one-camera group when present.
      final legacy = p.getString(lastDeviceIdKey);
      if (legacy == null || legacy.isEmpty) return const [];
      return [
        CameraMember(
          id: legacy,
          remoteId: legacy,
          displayName: 'GoPro',
        ),
      ];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          if (item is Map<String, dynamic>) CameraMember.fromJson(item)
          else if (item is Map)
            CameraMember.fromJson(Map<String, dynamic>.from(item)),
      ].where((m) => m.remoteId.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> setCameraGroup(List<CameraMember> members) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      cameraGroupJsonKey,
      jsonEncode([for (final m in members) m.toJson()]),
    );
    if (members.isNotEmpty) {
      await p.setString(lastDeviceIdKey, members.first.remoteId);
    }
  }
}
