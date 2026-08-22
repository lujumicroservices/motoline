import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_bootstrap.dart';

class DeviceTokenRepository {
  Future<void> upsert({
    required String token,
    required String platform,
  }) async {
    if (!SupabaseBootstrap.isReady) return;
    final me = SupabaseBootstrap.client.auth.currentUser?.id;
    if (me == null) return;
    await SupabaseBootstrap.client.from('device_tokens').upsert({
      'user_id': me,
      'token': token,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteToken(String token) async {
    if (!SupabaseBootstrap.isReady) return;
    await SupabaseBootstrap.client
        .from('device_tokens')
        .delete()
        .eq('token', token);
  }

  Future<void> deleteMine() async {
    if (!SupabaseBootstrap.isReady) return;
    final me = SupabaseBootstrap.client.auth.currentUser?.id;
    if (me == null) return;
    await SupabaseBootstrap.client
        .from('device_tokens')
        .delete()
        .eq('user_id', me);
  }
}

final deviceTokenRepositoryProvider = Provider<DeviceTokenRepository>((ref) {
  return DeviceTokenRepository();
});

String pushPlatformName() {
  if (kIsWeb) return 'android';
  if (Platform.isIOS) return 'ios';
  return 'android';
}
