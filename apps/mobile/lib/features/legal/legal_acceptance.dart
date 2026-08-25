import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../moderation/content_moderation_repository.dart';

class LegalAcceptance {
  static const prefKey = 'terms_accepted_v1';

  static Future<bool> hasAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
    await ContentModerationRepository.acceptGuidelines();
  }
}

final termsAcceptedProvider = FutureProvider<bool>((ref) {
  return LegalAcceptance.hasAccepted();
});
