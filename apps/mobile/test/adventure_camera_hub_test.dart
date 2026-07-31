import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/adventure_camera/adventure_camera_hub.dart';
import 'package:motoline/features/adventure_camera/adventure_camera_prefs.dart';
import 'package:motoline/features/adventure_camera/models/adventure_camera_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('hub stays disabled until lab enabled', () async {
    final hub = AdventureCameraHub();
    await hub.hydrate();
    expect(hub.isLabEnabled, isFalse);
    expect(hub.status.phase, AdventureCameraPhase.disabled);

    await hub.onRideStarted();
    expect(hub.status.phase, AdventureCameraPhase.disabled);
    await hub.dispose();
  });

  test('simulated backend records on ride hooks', () async {
    SharedPreferences.setMockInitialValues({
      AdventureCameraPrefs.labEnabledKey: true,
      AdventureCameraPrefs.syncWithRideKey: true,
      AdventureCameraPrefs.backendKey: AdventureCameraPrefs.backendSimulated,
    });

    final hub = AdventureCameraHub();
    await hub.hydrate();
    expect(hub.isLabEnabled, isTrue);
    expect(hub.backendId, 'simulated');

    await hub.onRideStarted();
    expect(hub.status.phase, AdventureCameraPhase.recording);

    await hub.onRideStopped();
    expect(hub.status.phase, AdventureCameraPhase.ready);
    await hub.dispose();
  });
}
