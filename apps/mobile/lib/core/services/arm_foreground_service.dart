import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Keeps a Dart isolate alive while "Armar auto" waits for motion with the
/// screen locked. Geolocator's FGS alone is not enough — GPS may continue
/// natively but Dart callbacks freeze until unlock.
@pragma('vm:entry-point')
void armForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(ArmLocationTaskHandler());
}

class ArmLocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('RiderLab arm FGS onStart (${starter.name})');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ignore: discarded_futures
    _pollAndSend(timestamp);
  }

  Future<void> _pollAndSend(DateTime timestamp) async {
    try {
      final LocationSettings settings;
      if (!kIsWeb && Platform.isAndroid) {
        settings = AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: const Duration(seconds: 8),
        );
      } else {
        settings = const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      FlutterForegroundTask.sendDataToMain(<String, dynamic>{
        'type': 'arm_gps',
        'lat': pos.latitude,
        'lng': pos.longitude,
        'speed': pos.speed.isNaN || pos.speed < 0 ? null : pos.speed,
        'accuracy': pos.accuracy,
        'ts': pos.timestamp.millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('RiderLab arm FGS GPS: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('RiderLab arm FGS onDestroy (timeout=$isTimeout)');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }
}

/// Init + start/stop helpers for the arm-auto foreground service.
class ArmForegroundService {
  ArmForegroundService._();

  static bool _inited = false;
  static DataCallback? _callback;

  static void ensureInitialized() {
    if (_inited) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'riderlab_arm_auto',
        channelName: 'Arm auto-ride',
        channelDescription:
            'Keeps GPS alive while waiting to auto-start with the screen off.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // 1 Hz is enough for arm detection and survives screen-off better.
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _inited = true;
  }

  static Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final n = await FlutterForegroundTask.checkNotificationPermission();
    if (n != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  static Future<bool> start({
    required DataCallback onData,
    String title = 'RiderLab',
    String text = 'Armed — waiting to auto-start (screen can be locked)…',
  }) async {
    ensureInitialized();
    await requestPermissions();

    if (_callback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_callback!);
    }
    _callback = onData;
    FlutterForegroundTask.addTaskDataCallback(onData);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: title,
      notificationText: text,
      callback: armForegroundStartCallback,
    );
    return result is ServiceRequestSuccess;
  }

  static Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static Future<void> stop() async {
    if (_callback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_callback!);
      _callback = null;
    }
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
