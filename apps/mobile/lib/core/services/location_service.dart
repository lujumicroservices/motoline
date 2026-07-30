import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    this.message,
  });

  final bool granted;
  final String? message;
}

class LocationService {
  Future<LocationPermissionResult> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationPermissionResult(
        granted: false,
        message: 'Turn on location services to record your line.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationPermissionResult(
        granted: false,
        message: 'Location permission is required to draw your pilot line.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return const LocationPermissionResult(
        granted: false,
        message: 'Enable location in Settings, then try again.',
      );
    }

    if (!kIsWeb && Platform.isAndroid) {
      final notif = await Permission.notification.request();
      if (!notif.isGranted) {
        // Still allow recording; FGS notification may be limited on some OEMs.
      }
    }

    // Best-effort: request "always" so glorieta loops survive screen-off.
    await Permission.locationAlways.request();

    return const LocationPermissionResult(granted: true);
  }

  /// ~1 Hz navigation stream with Android foreground service + wake lock.
  Stream<Position> watchPositions() {
    if (!kIsWeb && Platform.isAndroid) {
      return Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'MotoLine',
            notificationText: 'Recording your pilot line…',
            notificationChannelName: 'Ride recording',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      return Geolocator.getPositionStream(
        locationSettings: AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.automotiveNavigation,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        ),
      );
    }

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    );
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Max plausible motorcycle displacement for [dtSeconds], plus GPS error pad.
double maxPlausibleJumpMeters({
  required double dtSeconds,
  required double accuracyMeters,
  double previousAccuracyMeters = 10,
}) {
  final dt = dtSeconds.clamp(0.05, 45.0);
  // 70 m/s ≈ 252 km/h hard ceiling for filtering teleports only.
  const maxSpeedMps = 70.0;
  return maxSpeedMps * dt + accuracyMeters + previousAccuracyMeters + 15;
}

double clampLeanDegrees(double lean) => lean.clamp(-70.0, 70.0);

/// Phone-mounted lean proxy from gravity (degrees). Positive = lean right.
/// Best with phone fixed in portrait, screen facing the rider.
double leanFromAccelerometer({
  required double x,
  required double y,
  required double z,
}) {
  final leanRad = math.atan2(-x, math.sqrt(y * y + z * z));
  return clampLeanDegrees(leanRad * 180 / math.pi);
}
