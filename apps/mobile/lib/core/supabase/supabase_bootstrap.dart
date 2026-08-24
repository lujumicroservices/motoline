import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Boots the RiderLab Supabase project (not Luju POS / auto).
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _ready = false;
  static bool get isReady => _ready;

  /// Last session error (e.g. not signed in) for UI.
  static String? lastAuthError;

  /// Signed-in user with a real identity (Google / email).
  static User? get permanentUser {
    if (!_ready) return null;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return user;
  }

  static String? get permanentUserId => permanentUser?.id;

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
    await _dropAnonymousSession();
  }

  /// Closed beta: leftover guest sessions are discarded. Riders sign in fresh.
  static Future<void> _dropAnonymousSession() async {
    final user = client.auth.currentUser;
    if (user == null || !user.isAnonymous) return;
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('RiderLab drop anonymous session: $e');
    }
  }

  static SupabaseClient get client {
    if (!_ready) {
      throw StateError('SupabaseBootstrap.init() was not called');
    }
    return Supabase.instance.client;
  }

  /// Restores a permanent (Google / email) session. Never creates anonymous
  /// guests. Cloud callers must treat `null` as signed out.
  static Future<Session?> ensureSession() async {
    lastAuthError = null;
    final auth = client.auth;
    final existing = auth.currentSession;
    if (existing == null) {
      lastAuthError = 'Sign in required';
      return null;
    }
    if (existing.user.isAnonymous) {
      lastAuthError = 'Sign in required';
      return null;
    }
    await ensureProfileForUser(existing.user.id);
    await _syncLinkedNameIfNeeded(existing.user);
    return existing;
  }

  /// If already linked to Google, push name into profiles (fixes pre-sync users).
  static Future<void> _syncLinkedNameIfNeeded(User user) async {
    if (user.isAnonymous) return;
    try {
      final meta = user.userMetadata;
      String? name;
      for (final key in ['full_name', 'name', 'user_name', 'preferred_username']) {
        final v = meta?[key];
        if (v is String && v.trim().isNotEmpty) {
          name = v.trim();
          break;
        }
      }
      if (name == null) {
        for (final identity in user.identities ?? const <UserIdentity>[]) {
          if (identity.provider == 'anonymous') continue;
          final data = identity.identityData;
          for (final key in [
            'full_name',
            'name',
            'user_name',
            'preferred_username',
          ]) {
            final v = data?[key];
            if (v is String && v.trim().isNotEmpty) {
              name = v.trim();
              break;
            }
          }
          if (name != null) break;
          final identityEmail = (data?['email'] as String?)?.trim();
          if (identityEmail != null && identityEmail.isNotEmpty) {
            name = identityEmail;
            break;
          }
        }
      }
      name ??= user.email?.trim();
      if (name == null || name.isEmpty) return;

      await client.from('profiles').update({
        'display_name': name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
      debugPrint('RiderLab synced linked profile name: $name');
    } catch (e) {
      debugPrint('RiderLab linked profile sync: $e');
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
      debugPrint('RiderLab profile upsert: $e');
    }
  }
}
