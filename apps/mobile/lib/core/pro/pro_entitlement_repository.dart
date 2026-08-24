import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_bootstrap.dart';
import 'partner_code.dart';
import 'pro_entitlement.dart';

class ProEntitlementRepository {
  ProEntitlementRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    if (!SupabaseBootstrap.isReady) return null;
    return SupabaseBootstrap.client;
  }

  Future<ProRpcResult> status() => _rpc('my_pro_status');

  Future<ProRpcResult> startTrial() => _rpc('start_pro_trial');

  Future<ProRpcResult> redeem(String code) {
    return _rpc(
      'redeem_partner_code',
      params: {'p_code': normalizePartnerProCode(code)},
    );
  }

  Future<ProRpcResult> staffCreateCode({String? label}) {
    return _rpc(
      'staff_create_partner_code',
      params: {'p_label': label},
    );
  }

  Future<ProRpcResult> _rpc(
    String name, {
    Map<String, dynamic>? params,
  }) async {
    final client = _supabase;
    if (client == null || client.auth.currentUser == null) {
      return const ProRpcResult(ok: false, error: 'not_authenticated');
    }
    try {
      final raw = params == null
          ? await client.rpc(name)
          : await client.rpc(name, params: params);
      return ProRpcResult.fromJson(raw);
    } catch (e, st) {
      debugPrint('Pro RPC $name failed: $e\n$st');
      return ProRpcResult(ok: false, error: 'rpc_failed');
    }
  }
}
