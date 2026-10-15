import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profilesKey = 'metrica_paddock_wifi_profiles_v1';
const _legacyPasswordsKey = 'metrica_paddock_wifi_v1';
const _seededKey = 'metrica_paddock_wifi_seeded_v2';
const _platform = MethodChannel('com.rawthrottle.riderlab/platform');

/// A Wi‑Fi network the rider can push to Métrica over BLE.
class MetricaPaddockNetwork {
  const MetricaPaddockNetwork({
    required this.id,
    required this.label,
    required this.ssid,
    required this.password,
  });

  final String id;
  final String label;
  final String ssid;
  final String password;

  Map<String, String> toJson() => {
    'id': id,
    'label': label,
    'ssid': ssid,
    'password': password,
  };

  static MetricaPaddockNetwork? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString().trim() ?? '';
    final label = raw['label']?.toString().trim() ?? '';
    final ssid = raw['ssid']?.toString().trim() ?? '';
    final password = raw['password']?.toString() ?? '';
    if (id.isEmpty || ssid.isEmpty) return null;
    return MetricaPaddockNetwork(
      id: id,
      label: label.isEmpty ? ssid : label,
      ssid: ssid,
      password: password,
    );
  }
}

/// Built-in paddock / phone-hotspot networks for BLE Wi‑Fi push.
///
/// Métrica (ESP32 Basic) is **2.4 GHz only** — both of these expose 2.4.
const kDefaultPaddockNetworks = <MetricaPaddockNetwork>[
  MetricaPaddockNetwork(
    id: 'infinitum9bb9',
    label: 'Infinitum (casa)',
    ssid: 'INFINITUM9BB9',
    password: 'ZxHYmwcy9V',
  ),
  MetricaPaddockNetwork(
    id: 'galaxy-hotspot',
    label: 'Hotspot Galaxy S25',
    ssid: 'Galaxy S25 Ultra 65E5',
    password: '123456789',
  ),
];

/// Phone Wi‑Fi helpers for Métrica paddock pairing.
class MetricaPaddockWifi {
  const MetricaPaddockWifi();

  /// Current STA SSID, or null if unknown / not on Wi‑Fi.
  Future<String?> currentSsid() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    try {
      final raw = await _platform
          .invokeMethod<String>('currentWifiSsid')
          .timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      return _normalizeSsid(raw);
    } catch (_) {
      return null;
    }
  }

  /// Networks available in the BLE Wi‑Fi picker (seeded defaults + saved).
  Future<List<MetricaPaddockNetwork>> networks() async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureSeeded(prefs);
    final list = _decodeProfiles(prefs.getString(_profilesKey));
    if (list.isEmpty) return List.of(kDefaultPaddockNetworks);
    return list;
  }

  Future<void> upsert(MetricaPaddockNetwork network) async {
    final prefs = await SharedPreferences.getInstance();
    await _ensureSeeded(prefs);
    final list = _decodeProfiles(prefs.getString(_profilesKey));
    final next = <MetricaPaddockNetwork>[
      for (final n in list)
        if (n.id != network.id) n,
      network,
    ];
    await prefs.setString(
      _profilesKey,
      jsonEncode([for (final n in next) n.toJson()]),
    );
  }

  Future<String?> savedPassword(String ssid) async {
    final key = _normalizeSsid(ssid);
    if (key == null) return null;
    for (final n in await networks()) {
      if (n.ssid == key) return n.password;
    }
    final prefs = await SharedPreferences.getInstance();
    final map = _decodeLegacy(prefs.getString(_legacyPasswordsKey));
    return map[key];
  }

  Future<void> remember({required String ssid, required String password}) async {
    final key = _normalizeSsid(ssid);
    if (key == null) return;
    final existing = await networks();
    final match = existing.where((n) => n.ssid == key).firstOrNull;
    await upsert(
      MetricaPaddockNetwork(
        id: match?.id ?? 'custom-${key.hashCode.toUnsigned(32).toRadixString(16)}',
        label: match?.label ?? key,
        ssid: key,
        password: password,
      ),
    );
  }

  Future<({String ssid, String password})?> autoCredentials() async {
    final ssid = await currentSsid();
    if (ssid == null) return null;
    final pass = await savedPassword(ssid);
    if (pass == null) return null;
    return (ssid: ssid, password: pass);
  }

  Future<void> _ensureSeeded(SharedPreferences prefs) async {
    if (prefs.getBool(_seededKey) == true) return;
    final existing = _decodeProfiles(prefs.getString(_profilesKey));
    if (existing.isEmpty) {
      await prefs.setString(
        _profilesKey,
        jsonEncode([for (final n in kDefaultPaddockNetworks) n.toJson()]),
      );
    } else {
      // Merge defaults by id without wiping rider edits.
      final byId = {for (final n in existing) n.id: n};
      for (final n in kDefaultPaddockNetworks) {
        byId.putIfAbsent(n.id, () => n);
      }
      await prefs.setString(
        _profilesKey,
        jsonEncode([for (final n in byId.values) n.toJson()]),
      );
    }
    await prefs.setBool(_seededKey, true);
  }

  static String? _normalizeSsid(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.isEmpty ||
        s == '<unknown ssid>' ||
        s == 'unknown ssid' ||
        s == '0x') {
      return null;
    }
    return s;
  }

  static List<MetricaPaddockNetwork> _decodeProfiles(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <MetricaPaddockNetwork>[];
      for (final item in decoded) {
        final network = MetricaPaddockNetwork.fromJson(item);
        if (network != null) out.add(network);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static Map<String, String> _decodeLegacy(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, String>{};
      decoded.forEach((key, value) {
        if (key is String && value is String) out[key] = value;
      });
      return out;
    } catch (_) {
      return {};
    }
  }
}
