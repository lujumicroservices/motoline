import 'package:flutter/foundation.dart';

import '../supabase/supabase_bootstrap.dart';

class LoggerPairResult {
  const LoggerPairResult({
    required this.deviceId,
    required this.deviceSecret,
    required this.ingestUrl,
  });

  final String deviceId;
  final String deviceSecret;
  final String ingestUrl;

  /// Serial command to paste into the Basic USB monitor.
  String get serialPairCommand =>
      'PAIR $deviceId|$deviceSecret|$ingestUrl';
}

/// Mints / claims pairing codes via Edge Function `pair-logger-device`.
class LoggerPairingService {
  Future<String> mintPairCode() async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    final session = await SupabaseBootstrap.ensureSession();
    if (session == null) throw StateError('Not signed in');

    final res = await SupabaseBootstrap.client.functions.invoke(
      'pair-logger-device',
      body: {'action': 'mint_code'},
    );
    final data = res.data;
    if (data is! Map || data['ok'] != true) {
      throw StateError('mint failed: $data');
    }
    return data['code'] as String;
  }

  /// Claim a code from a helper/device (returns secrets for serial PAIR).
  Future<LoggerPairResult> claimCode(String code, {String label = 'M5 Logger'}) async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Supabase not ready');
    }
    final res = await SupabaseBootstrap.client.functions.invoke(
      'pair-logger-device',
      body: {
        'action': 'claim_code',
        'code': code.trim().toUpperCase(),
        'label': label,
      },
    );
    final data = res.data;
    if (data is! Map || data['ok'] != true) {
      debugPrint('claim failed: $data');
      throw StateError('claim failed: $data');
    }
    return LoggerPairResult(
      deviceId: data['device_id'] as String,
      deviceSecret: data['device_secret'] as String,
      ingestUrl: data['ingest_url'] as String,
    );
  }
}
