import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_bootstrap.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseBootstrap.client;
});

final supabaseSessionProvider = StreamProvider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session);
});

/// One-shot: create anonymous session if needed (for cloud sync / compare).
final ensureSupabaseSessionProvider = FutureProvider<Session?>((ref) async {
  return SupabaseBootstrap.ensureSession();
});
