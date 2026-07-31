import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/supabase_bootstrap.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.init();
  try {
    await SupabaseBootstrap.ensureSession();
  } catch (_) {
    // Auth provider may be off; app still works offline.
  }
  runApp(const ProviderScope(child: CornerIqApp()));
}

class CornerIqApp extends ConsumerWidget {
  const CornerIqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'CornerIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Spanish is the product default when device locale is unsupported.
      localeResolutionCallback: (device, supported) {
        if (locale.languageCode == 'en' || locale.languageCode == 'es') {
          return locale;
        }
        for (final l in supported) {
          if (l.languageCode == device?.languageCode) return l;
        }
        return const Locale('es');
      },
      home: const HomeScreen(),
    );
  }
}
