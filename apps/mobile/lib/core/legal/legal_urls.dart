import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalUrls {
  static final terms = Uri.parse(
    'https://riderlab.rawthrottle.com.mx/legal/terms.html',
  );
  static final privacy = Uri.parse(
    'https://riderlab.rawthrottle.com.mx/legal/privacy.html',
  );
}

Future<bool> openLegalUrl(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> openLegalUrlOrSnack(BuildContext context, Uri uri) async {
  final ok = await openLegalUrl(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$uri')),
    );
  }
}
