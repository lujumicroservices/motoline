import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/features/adventure_camera/aggressive_riding_detector.dart';
import 'package:motoline/features/adventure_camera/adventure_camera_hub.dart';
import 'package:motoline/features/adventure_camera/adventure_camera_prefs.dart';
import 'package:motoline/features/adventure_camera/camera_zone_detector.dart';
import 'package:motoline/features/adventure_camera/models/adventure_camera_status.dart';
import 'package:motoline/features/adventure_camera/models/camera_zone.dart';
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
    expect(hub.status.phase, AdventureCameraPhase.idle);
    await hub.dispose();
  });

  test('zone-only mode waits until start geofence', () async {
    SharedPreferences.setMockInitialValues({
      AdventureCameraPrefs.labEnabledKey: true,
      AdventureCameraPrefs.syncWithRideKey: false,
      AdventureCameraPrefs.zonesEnabledKey: true,
      AdventureCameraPrefs.backendKey: AdventureCameraPrefs.backendSimulated,
    });

    final hub = AdventureCameraHub();
    await hub.hydrate();
    await hub.setZones([
      const CameraZone(
        id: 's1',
        latitude: 19.4,
        longitude: -99.1,
        action: CameraZoneAction.start,
        radiusMeters: 50,
        partnerId: 'e1',
      ),
      const CameraZone(
        id: 'e1',
        latitude: 19.41,
        longitude: -99.11,
        action: CameraZoneAction.stop,
        radiusMeters: 50,
        partnerId: 's1',
      ),
    ]);

    await hub.onRideStarted();
    expect(hub.status.phase, AdventureCameraPhase.idle);

    await hub.onLiveSample(latitude: 19.4, longitude: -99.1, speedKmh: 40);
    expect(hub.status.phase, AdventureCameraPhase.recording);

    await hub.onLiveSample(latitude: 19.41, longitude: -99.11, speedKmh: 40);
    expect(hub.status.phase, AdventureCameraPhase.idle);
    await hub.dispose();
  });

  test('start zones gate shutter even when sync-with-ride is on', () async {
    SharedPreferences.setMockInitialValues({
      AdventureCameraPrefs.labEnabledKey: true,
      AdventureCameraPrefs.syncWithRideKey: true,
      AdventureCameraPrefs.zonesEnabledKey: true,
      AdventureCameraPrefs.backendKey: AdventureCameraPrefs.backendSimulated,
    });

    final hub = AdventureCameraHub();
    await hub.hydrate();
    await hub.setZones([
      const CameraZone(
        id: 's1',
        latitude: 19.4,
        longitude: -99.1,
        action: CameraZoneAction.start,
        radiusMeters: 50,
      ),
    ]);

    await hub.onRideStarted();
    expect(hub.status.phase, AdventureCameraPhase.idle);
    expect(hub.status.isRecording, isFalse);

    await hub.onLiveSample(latitude: 19.4, longitude: -99.1, speedKmh: 40);
    expect(hub.status.phase, AdventureCameraPhase.recording);
    await hub.dispose();
  });

  test('camera group records on all simulated members', () async {
    SharedPreferences.setMockInitialValues({
      AdventureCameraPrefs.labEnabledKey: true,
      AdventureCameraPrefs.syncWithRideKey: true,
      AdventureCameraPrefs.backendKey: AdventureCameraPrefs.backendSimulated,
      AdventureCameraPrefs.cameraGroupJsonKey: '''
[{"id":"a","remote_id":"sim-a","name":"Cam A","enabled":true},
 {"id":"b","remote_id":"sim-b","name":"Cam B","enabled":true}]
''',
    });

    final hub = AdventureCameraHub();
    await hub.hydrate();
    expect(hub.cameraGroup.length, 2);
    expect(hub.backendId, 'camera_group');

    await hub.onRideStarted();
    // Group status updates are streamed; allow the aggregate emit to settle.
    await Future<void>.delayed(Duration.zero);
    expect(hub.status.phase, AdventureCameraPhase.recording);
    expect(hub.status.recordingCount, 2);
    expect(hub.status.memberCount, 2);

    await hub.onRideStopped();
    expect(hub.status.phase, AdventureCameraPhase.idle);
    await hub.dispose();
  });

  test('zone detector is edge-triggered', () {
    final d = CameraZoneDetector(
      zones: const [
        CameraZone(
          id: 'a',
          latitude: 0,
          longitude: 0,
          action: CameraZoneAction.start,
          radiusMeters: 40,
          partnerId: 'b',
        ),
      ],
    );
    expect(d.feed(latitude: 0, longitude: 0)?.action, CameraZoneAction.start);
    expect(d.feed(latitude: 0, longitude: 0), isNull);
    expect(d.feed(latitude: 1, longitude: 1), isNull);
    expect(d.feed(latitude: 0, longitude: 0)?.action, CameraZoneAction.start);
  });

  test('stop only fires after its partner start', () {
    final d = CameraZoneDetector(
      zones: const [
        CameraZone(
          id: 's1',
          latitude: 0,
          longitude: 0,
          action: CameraZoneAction.start,
          radiusMeters: 40,
          partnerId: 'e1',
        ),
        CameraZone(
          id: 'e1',
          latitude: 1,
          longitude: 1,
          action: CameraZoneAction.stop,
          radiusMeters: 40,
          partnerId: 's1',
        ),
        CameraZone(
          id: 'e2',
          latitude: 2,
          longitude: 2,
          action: CameraZoneAction.stop,
          radiusMeters: 40,
          partnerId: 's2',
        ),
      ],
    );
    // Unrelated stop before any start → ignored.
    expect(d.feed(latitude: 2, longitude: 2), isNull);
    // Partner stop before its start → ignored.
    expect(d.feed(latitude: 1, longitude: 1), isNull);
    expect(d.feed(latitude: 0, longitude: 0)?.action, CameraZoneAction.start);
    expect(d.feed(latitude: 1, longitude: 1)?.action, CameraZoneAction.stop);
    // Same stop again without re-arming start → ignored.
    expect(d.feed(latitude: 0.5, longitude: 0.5), isNull);
    expect(d.feed(latitude: 1, longitude: 1), isNull);
  });

  test('aggressive requires 85+ and constant lean changes, then pauses when calm', () {
    final d = AggressiveRidingDetector(
      changesToStart: 3,
      changeWindow: const Duration(seconds: 6),
      exitQuiet: const Duration(seconds: 2),
      startCooldown: Duration.zero,
    );
    final t0 = DateTime.utc(2026, 1, 1, 12);

    expect(
      d.feed(timestamp: t0, leanDegrees: 10, speedKmh: 90),
      isNull,
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 200)),
        leanDegrees: 20,
        speedKmh: 50,
      ),
      isNull,
      reason: 'lean change below min speed is ignored',
    );

    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 400)),
        leanDegrees: 5,
        speedKmh: 90,
      ),
      isNull,
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 600)),
        leanDegrees: 18,
        speedKmh: 92,
      ),
      isNull,
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 800)),
        leanDegrees: 6,
        speedKmh: 91,
      ),
      AggressiveRidingAction.start,
    );

    // Keep changing lean → stay recording.
    expect(
      d.feed(
        timestamp: t0.add(const Duration(seconds: 2)),
        leanDegrees: 20,
        speedKmh: 90,
      ),
      isNull,
    );

    // Calm lean → pause after exitQuiet.
    expect(
      d.feed(
        timestamp: t0.add(const Duration(seconds: 3)),
        leanDegrees: 21,
        speedKmh: 90,
      ),
      isNull,
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(seconds: 6)),
        leanDegrees: 21.2,
        speedKmh: 90,
      ),
      AggressiveRidingAction.pause,
    );
  });

  test('aggressive detector starts on linked lean flips at speed', () {
    final d = AggressiveRidingDetector(
      changesToStart: 2,
      leanChangeDegrees: 99,
      startCooldown: Duration.zero,
    );
    final t0 = DateTime.utc(2026, 1, 1, 12);
    expect(
      d.feed(timestamp: t0, leanDegrees: -25, speedKmh: 95),
      isNull,
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 400)),
        leanDegrees: 25,
        speedKmh: 95,
      ),
      isNull,
      reason: 'one flip not enough',
    );
    expect(
      d.feed(
        timestamp: t0.add(const Duration(milliseconds: 800)),
        leanDegrees: -25,
        speedKmh: 95,
      ),
      AggressiveRidingAction.start,
    );
  });
}
