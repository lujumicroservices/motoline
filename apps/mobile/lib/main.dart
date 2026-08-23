import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/impersonation_gate.dart';
import 'core/auth/impersonation_store.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/services/arm_foreground_service.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/home/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'providers/locale_provider.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ArmForegroundService.ensureInitialized();
  await SupabaseBootstrap.init();
  try {
    await SupabaseBootstrap.ensureSession();
  } catch (_) {
    // Auth provider may be off; app still works offline.
  }
  await ImpersonationStore.hydrate();
  await PushNotificationService.instance.init();
  runApp(const ProviderScope(child: RiderLabApp()));
}

class RiderLabApp extends ConsumerWidget {
  const RiderLabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'RiderLab',
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
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
      home: const _BootHome(),
      builder: (context, child) {
        return ImpersonationGate(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _BootHome extends StatefulWidget {
  const _BootHome();

  @override
  State<_BootHome> createState() => _BootHomeState();
}

class _BootHomeState extends State<_BootHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.openPendingRodadaIfAny();
    });
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
