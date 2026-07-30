import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Boots the CornerIQ Supabase project (not Luju POS / auto).
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _ready = false;
  static bool get isReady => _ready;

  static Future<void> init() async {
    if (_ready) return;

    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final publishable = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim();
    final anon = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    final key = (publishable != null && publishable.isNotEmpty)
        ? publishable
        : anon;
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
        '(or SUPABASE_ANON_KEY) in apps/mobile/.env',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: key,
    );
    _ready = true;
  }

  static SupabaseClient get client {
    if (!_ready) {
      throw StateError('SupabaseBootstrap.init() was not called');
    }
    return Supabase.instance.client;
  }

  /// Ensures a session exists (anonymous) so RLS-backed sync can run.
  static Future<Session?> ensureSession() async {
    final auth = client.auth;
    final existing = auth.currentSession;
    if (existing != null) return existing;

    final response = await auth.signInAnonymously();
    return response.session;
  }
}
