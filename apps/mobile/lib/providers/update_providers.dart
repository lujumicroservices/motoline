import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_update_service.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

/// Latest available update, or null when already up to date / unsupported.
final appUpdateCheckProvider =
    FutureProvider.autoDispose<AppUpdateInfo?>((ref) async {
  return ref.watch(appUpdateServiceProvider).checkForUpdate();
});

final dismissedUpdateTagProvider = StateProvider<String?>((ref) => null);
