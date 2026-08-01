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

enum GpsWarmupPhase {
  permissions,
  searching,
  locking,
  ready,
  timeout,
}

/// Progress while GNSS settles before the first recorded point.
class GnssWarmupStatus {
  const GnssWarmupStatus({
    required this.phase,
    this.accuracyMeters,
    this.message,
  });

  final GpsWarmupPhase phase;
  final double? accuracyMeters;
  final String? message;

  bool get isReady => phase == GpsWarmupPhase.ready;

  /// 0–1 toward the warm target accuracy (higher = better lock).
  double get lockProgress {
    final acc = accuracyMeters;
    if (acc == null || acc <= 0) return 0;
    if (acc <= LocationService.warmTargetAccuracyMeters) return 1;
    final t = (LocationService.maxAcceptAccuracyMeters - acc) /
        (LocationService.maxAcceptAccuracyMeters -
            LocationService.warmTargetAccuracyMeters);
    return t.clamp(0.0, 0.95);
  }
}

/// High-precision profile tuned for flagship Android (Galaxy S25 Ultra).
///
/// S25 Ultra has multi-band GNSS; we ask Fused Location for the fastest
/// high-accuracy stream Android will deliver (often ~1 Hz raw GNSS, with
/// denser fused updates when motion/sensors allow).
class LocationService {
  /// Target GPS/fused interval. Lower = denser pilot line (more battery).
  static const Duration sampleInterval = Duration(milliseconds: 100);

  /// Reject only garbage fixes; keep urban canyon continuity.
  static const double maxAcceptAccuracyMeters = 40;

  /// Prefer starting once horizontal accuracy is at least this good.
  static const double warmTargetAccuracyMeters = 10;

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
      await Permission.notification.request();
    }

    // Always / background — required for glorieta loops with screen off.
    await Permission.locationAlways.request();

    return const LocationPermissionResult(granted: true);
  }

  /// Warm the GNSS receiver so the first recorded points are accurate.
  ///
  /// Yields live accuracy so the UI can show lock progress instead of freezing.
  Stream<GnssWarmupStatus> warmUpGnss({
    Duration timeout = const Duration(seconds: 8),
  }) async* {
    yield const GnssWarmupStatus(
      phase: GpsWarmupPhase.searching,
      message: 'Looking for satellites…',
    );

    final deadline = DateTime.now().add(timeout);
    Position? best;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: _highPrecisionSettings(forSingleShot: true),
        );
        best = position;
        final acc = position.accuracy;
        if (acc > 0 && acc <= warmTargetAccuracyMeters) {
          yield GnssWarmupStatus(
            phase: GpsWarmupPhase.ready,
            accuracyMeters: acc,
            message: 'GPS ready (±${acc.toStringAsFixed(0)} m)',
          );
          return;
        }
        yield GnssWarmupStatus(
          phase: GpsWarmupPhase.locking,
          accuracyMeters: acc > 0 ? acc : null,
          message: acc > 0
              ? 'Warming GPS (±${acc.toStringAsFixed(0)} m)…'
              : 'Warming GPS…',
        );
      } catch (_) {
        yield const GnssWarmupStatus(
          phase: GpsWarmupPhase.searching,
          message: 'Looking for satellites…',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final bestAcc = best?.accuracy;
    yield GnssWarmupStatus(
      phase: GpsWarmupPhase.timeout,
      accuracyMeters: (bestAcc != null && bestAcc > 0) ? bestAcc : null,
      message: bestAcc != null && bestAcc > 0
          ? 'Starting with ±${bestAcc.toStringAsFixed(0)} m — keep sky view open'
          : 'Starting — keep sky view open for a better lock',
    );
  }

  /// Max-rate navigation stream with Android foreground service + wake lock.
  ///
  /// Keep this stream alive across screen-off; do not cancel+restart it from
  /// background (Android 12+ blocks new FGS starts when the screen is locked).
  Stream<Position> watchPositions({
    String notificationTitle = 'RiderLab',
    String notificationText = 'High-precision recording…',
  }) {
    return Geolocator.getPositionStream(
      locationSettings: _highPrecisionSettings(
        forSingleShot: false,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
      ),
    );
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _highPrecisionSettings(forSingleShot: true),
      );
    } catch (_) {
      return null;
    }
  }

  LocationSettings _highPrecisionSettings({
    required bool forSingleShot,
    String notificationTitle = 'RiderLab',
    String notificationText = 'High-precision recording…',
  }) {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        // Highest priority available in geolocator.
        accuracy: LocationAccuracy.bestForNavigation,
        // Never skip fixes by distance — capture every glorieta sample.
        distanceFilter: 0,
        // Ask for ~10 Hz; chip/OS may deliver ~1–5 Hz outdoors.
        intervalDuration: forSingleShot ? null : sampleInterval,
        // Fused Location (Google) — better than raw LocationManager on Samsung.
        // Changelog: forceLocationManager:true caused very inaccurate readings.
        forceLocationManager: false,
        // Mean sea level altitude when available.
        useMSLAltitude: true,
        foregroundNotificationConfig: forSingleShot
            ? null
            : ForegroundNotificationConfig(
                notificationTitle: notificationTitle,
                notificationText: notificationText,
                notificationChannelName: 'Ride recording',
                enableWakeLock: true,
                setOngoing: true,
              ),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
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
