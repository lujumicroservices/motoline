import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Boots the CornerIQ Supabase project (not Luju POS / auto).
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _ready = false;
  static bool get isReady => _ready;

  /// Last session error (e.g. Anonymous provider disabled) for UI.
  static String? lastAuthError;

  static Future<void> init() async {
    if (_ready) return;

    await dotenv.load(fileName: '.env');
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final publishable = dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
    final anon = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    // Prefer classic JWT anon key for Auth reliability on mobile.
    final key = anon.isNotEmpty
        ? anon
        : (publishable.isNotEmpty ? publishable : '');
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL and SUPABASE_ANON_KEY '
        '(or SUPABASE_PUBLISHABLE_KEY) in apps/mobile/.env',
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
    lastAuthError = null;
    final auth = client.auth;
    final existing = auth.currentSession;
    if (existing != null) {
      await ensureProfileForUser(existing.user.id);
      return existing;
    }

    try {
      final response = await auth.signInAnonymously();
      final session = response.session;
      if (session == null) {
        lastAuthError = 'Anonymous sign-in returned no session';
        return null;
      }
      await ensureProfileForUser(session.user.id);
      return session;
    } on AuthException catch (e) {
      lastAuthError = e.message;
      debugPrint('CornerIQ auth: ${e.message}');
      rethrow;
    } catch (e) {
      lastAuthError = '$e';
      debugPrint('CornerIQ auth: $e');
      rethrow;
    }
  }

  /// Trigger should create the row; upsert covers older projects / races.
  /// Never send null display_name — that would wipe the rider alias.
  static Future<void> ensureProfileForUser(String userId) async {
    try {
      final existing = await client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing == null) {
        await client.from('profiles').insert({
          'id': userId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client.from('profiles').update({
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);
      }
    } catch (e) {
      debugPrint('CornerIQ profile upsert: $e');
    }
  }
}
