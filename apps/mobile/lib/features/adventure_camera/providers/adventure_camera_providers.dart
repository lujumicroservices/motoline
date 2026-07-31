import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adventure_camera_hub.dart';
import '../adventure_camera_prefs.dart';
import '../models/adventure_camera_status.dart';

final adventureCameraHubProvider = Provider<AdventureCameraHub>((ref) {
  final hub = AdventureCameraHub();
  ref.onDispose(() {
    // ignore: discarded_futures
    hub.dispose();
  });
  return hub;
});

/// Hydrates prefs once; watch from Settings / lifecycle binder.
final adventureCameraHydratedProvider = FutureProvider<AdventureCameraHub>((ref) async {
  final hub = ref.watch(adventureCameraHubProvider);
  await hub.hydrate();
  return hub;
});

final adventureCameraStatusProvider =
    StreamProvider.autoDispose<AdventureCameraStatus>((ref) async* {
  final hub = await ref.watch(adventureCameraHydratedProvider.future);
  yield hub.status;
  yield* hub.statusStream;
});

final adventureCameraLabEnabledProvider =
    Provider.autoDispose<bool>((ref) {
  ref.watch(adventureCameraHydratedProvider);
  return ref.watch(adventureCameraHubProvider).isLabEnabled;
});

final adventureCameraBackendProvider =
    FutureProvider.autoDispose<String>((ref) async {
  ref.watch(adventureCameraHydratedProvider);
  return AdventureCameraPrefs.backend();
});
