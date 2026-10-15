import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';

class LoggerPairResult {
  const LoggerPairResult({
    required this.deviceId,
    required this.deviceSecret,
    required this.ingestUrl,
  });

  final String deviceId;
  final String deviceSecret;

  /// `ingest_url` from claim/create, forwarded unchanged into PAIR.
  ///
  /// The logger uploads to whatever https URL is stored here, with the key
  /// in the `X-Logger-Key` header. Do not rewrite the URL in the app.
  final String ingestUrl;

  /// Serial command to paste into the Basic USB monitor.
  String get serialPairCommand => 'PAIR $deviceId|$deviceSecret|$ingestUrl';
}

/// Mints / claims pairing codes via Edge Function `pair-logger-device`.
abstract class LoggerPairingApi {
  Future<String> mintPairCode();

  Future<LoggerPairResult> claimCode(String code, {String label = 'M5 Logger'});

  /// One-hop create for BLE / in-app (no short-lived code).
  Future<LoggerPairResult> createDevice({String label = 'M5 Logger'});
}

class LoggerPairingService implements LoggerPairingApi {
  @override
  Future<String> mintPairCode() async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    final session = await SupabaseBootstrap.ensureSession();
    if (session == null) throw StateError('Not signed in');

    final data = await _invoke({'action': 'mint_code'});
    if (data['ok'] != true) {
      throw StateError('mint failed: ${_safeError(data)}');
    }
    final code = data['code'];
    if (code is! String || code.isEmpty) {
      throw StateError('mint failed: missing code');
    }
    return code;
  }

  /// Claim a code from a helper/device (returns secrets for serial PAIR).
  @override
  Future<LoggerPairResult> claimCode(
    String code, {
    String label = 'M5 Logger',
  }) async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    final session = await SupabaseBootstrap.ensureSession();
    if (session == null) throw StateError('Not signed in');

    final data = await _invoke({
      'action': 'claim_code',
      'code': code.trim().toUpperCase(),
      'label': label,
    });
    return _parseDevice(data, failure: 'claim failed');
  }

  @override
  Future<LoggerPairResult> createDevice({String label = 'M5 Logger'}) async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    final session = await SupabaseBootstrap.ensureSession();
    if (session == null) throw StateError('Not signed in');

    final data = await _invoke({
      'action': 'create_device',
      'label': label,
    });
    return _parseDevice(data, failure: 'create failed');
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await SupabaseBootstrap.client.functions.invoke(
        'pair-logger-device',
        body: body,
      );
      final data = res.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw StateError('bad response');
    } on FunctionException catch (error) {
      throw StateError(_functionFailure(error));
    }
  }

  LoggerPairResult _parseDevice(
    Map<String, dynamic> data, {
    required String failure,
  }) {
    if (data['ok'] != true) {
      // Never put raw body on the exception — it can include device_secret.
      throw StateError('$failure: ${_safeError(data)}');
    }
    final deviceId = data['device_id'];
    final secret = data['device_secret'];
    final ingestUrl = data['ingest_url'];
    if (deviceId is! String ||
        secret is! String ||
        ingestUrl is! String ||
        deviceId.isEmpty ||
        secret.isEmpty ||
        ingestUrl.isEmpty) {
      throw StateError('$failure: missing fields');
    }
    return LoggerPairResult(
      deviceId: deviceId,
      deviceSecret: secret,
      ingestUrl: ingestUrl,
    );
  }

  /// Safe for UI / logs. Never includes secrets.
  static String _safeError(Map<String, dynamic> data) {
    final err = data['error']?.toString().trim() ?? '';
    final step = data['step']?.toString().trim() ?? '';
    if (err.isEmpty) return 'unknown';
    // Strip anything that looks like a secret blob.
    if (err.length > 120 || err.toLowerCase().contains('secret')) {
      return step.isEmpty ? 'server' : step;
    }
    return step.isEmpty ? err : '$step: $err';
  }

  static String _functionFailure(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final map = Map<String, dynamic>.from(details);
      final safe = _safeError(map);
      return 'http ${error.status} $safe';
    }
    return 'http ${error.status}';
  }
}
