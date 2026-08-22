import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last FCM sends from this install, for Settings troubleshooting.
class PushDiagnostics {
  PushDiagnostics._();

  static const _prefsKey = 'push_diagnostics_log';
  static const _maxLines = 8;

  static String? lastLine;
  static DateTime? lastAt;
  static List<String> history = [];
  static bool _hydrated = false;

  static bool get hasError {
    final line = lastLine;
    return line != null &&
        (line.contains('error=') || line.contains('skipped='));
  }

  static Future<void> hydrate() async {
    if (_hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey) ?? [];
      history = [...stored, ...history];
      if (history.length > _maxLines) {
        history = history.sublist(history.length - _maxLines);
      }
      if (history.isNotEmpty) {
        lastLine = history.last;
      }
      _hydrated = true;
      await prefs.setStringList(_prefsKey, history);
    } catch (e) {
      _hydrated = true;
      debugPrint('PushDiagnostics.hydrate: $e');
    }
  }

  static void record({
    required String fn,
    int? sent,
    String? skipped,
    String? error,
  }) {
    lastAt = DateTime.now();
    final parts = <String>[
      fn,
      if (sent != null) 'sent=$sent',
      if (skipped != null && skipped.isNotEmpty) 'skipped=$skipped',
      if (error != null && error.isNotEmpty) 'error=$error',
    ];
    lastLine = '${lastAt!.toIso8601String()} · ${parts.join(' · ')}';
    history = [...history, lastLine!];
    if (history.length > _maxLines) {
      history = history.sublist(history.length - _maxLines);
    }
    debugPrint('PushDiagnostics: $lastLine');
    if (_hydrated) {
      unawaited(_persist());
    }
  }

  static void recordError(String fn, Object e) {
    record(fn: fn, error: e.toString());
  }

  static void recordFunctionData(String fn, dynamic data) {
    if (data is Map) {
      final err = data['error']?.toString();
      final detail = data['detail']?.toString();
      final skipped = data['skipped']?.toString();
      final sentRaw = data['sent'];
      final sent = sentRaw is int
          ? sentRaw
          : int.tryParse(sentRaw?.toString() ?? '');
      record(
        fn: fn,
        sent: sent,
        skipped: skipped,
        error: err == null
            ? null
            : (detail == null || detail.isEmpty ? err : '$err ($detail)'),
      );
      return;
    }
    if (data == null) {
      record(fn: fn, error: 'empty_response');
      return;
    }
    record(fn: fn, error: 'bad_response');
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, history);
    } catch (e) {
      debugPrint('PushDiagnostics.persist: $e');
    }
  }
}
