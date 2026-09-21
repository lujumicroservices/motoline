import 'dart:convert';

import 'package:ride_core/ride_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _surveyKey = 'offroad_circuit_survey_v1';

Future<OffroadCircuitSurvey?> loadOffroadCircuitSurvey() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_surveyKey);
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    return OffroadCircuitSurvey.fromJson(Map<String, dynamic>.from(json));
  } catch (_) {
    return null;
  }
}

Future<void> saveOffroadCircuitSurvey(OffroadCircuitSurvey survey) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_surveyKey, jsonEncode(survey.toJson()));
}
