import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/supabase/supabase_bootstrap.dart';
import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.init();
  // Anonymous session so shared-route sync/compare can use RLS later.
  try {
    await SupabaseBootstrap.ensureSession();
  } catch (_) {
    // Auth provider may be off; app still works offline.
  }
  runApp(const ProviderScope(child: CornerIqApp()));
}

class CornerIqApp extends StatelessWidget {
  const CornerIqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CornerIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
