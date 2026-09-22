import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'circuit_8h_models.dart';

const _prefsKey = 'circuit_8h_project_v1';
const _lastUploadKey = 'circuit_8h_last_upload_at';

Future<Circuit8hProject> loadCircuit8hProject() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null || raw.isEmpty) return const Circuit8hProject();
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return const Circuit8hProject();
    return Circuit8hProject.fromJson(Map<String, dynamic>.from(json));
  } catch (_) {
    return const Circuit8hProject();
  }
}

Future<void> saveCircuit8hProject(Circuit8hProject project) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, jsonEncode(project.toJson()));
}

Future<String?> loadCircuit8hLastUploadAt() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_lastUploadKey);
}

Future<void> saveCircuit8hLastUploadAt(String isoUtc) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_lastUploadKey, isoUtc);
}
