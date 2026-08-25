import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationPermissionDenyReason {
  servicesOff,
  denied,
  deniedForever,
}

class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    this.reason,
  });

  final bool granted;
  final LocationPermissionDenyReason? reason;
}

class LocationDeniedException implements Exception {
  const LocationDeniedException(this.reason);

  final LocationPermissionDenyReason reason;

  @override
  String toString() => reason.name;
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
  });

  final GpsWarmupPhase phase;
  final double? accuracyMeters;

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

  /// True when location services are on and background ("always") is granted.
  Future<bool> hasRecordingPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  Future<LocationPermissionResult> ensurePermission() async {
    if (await hasRecordingPermission()) {
      return const LocationPermissionResult(granted: true);
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationPermissionResult(
        granted: false,
        reason: LocationPermissionDenyReason.servicesOff,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationPermissionResult(
        granted: false,
        reason: LocationPermissionDenyReason.denied,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      await openAppSettings();
      return const LocationPermissionResult(
        granted: false,
        reason: LocationPermissionDenyReason.deniedForever,
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
    yield const GnssWarmupStatus(phase: GpsWarmupPhase.searching);

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
          );
          return;
        }
        yield GnssWarmupStatus(
          phase: GpsWarmupPhase.locking,
          accuracyMeters: acc > 0 ? acc : null,
        );
      } catch (_) {
        yield const GnssWarmupStatus(phase: GpsWarmupPhase.searching);
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final bestAcc = best?.accuracy;
    yield GnssWarmupStatus(
      phase: GpsWarmupPhase.timeout,
      accuracyMeters: (bestAcc != null && bestAcc > 0) ? bestAcc : null,
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

/// Legacy closest-axis lean (debug / IMU lab "App lean" only).
///
/// Production uses LeanEngine signed bike lean. Do not call this for new
/// ride samples — it switches axes mid-tilt.
double leanFromAccelerometer({
  required double x,
  required double y,
  required double z,
}) {
  final g = math.sqrt(x * x + y * y + z * z);
  if (g < 1e-3) return 0;

  final gx = x / g;
  final gy = y / g;
  final gz = z / g;
  final absX = gx.abs();
  final absY = gy.abs();
  final absZ = gz.abs();

  late final double magRad;
  late final double sign;

  if (absY >= absX && absY >= absZ) {
    // Portrait-ish: Y closest to up (pocket / upright hold).
    magRad = math.atan2(math.sqrt(gx * gx + gz * gz), absY);
    // Prefer roll sign; if pitch dominates (wall tip), use pitch sign.
    sign = absX >= absZ
        ? (gx == 0 ? 1.0 : -gx.sign)
        : (gz == 0 ? 1.0 : gz.sign);
  } else if (absX >= absY && absX >= absZ) {
    // Landscape-ish: X closest to up.
    magRad = math.atan2(math.sqrt(gy * gy + gz * gz), absX);
    sign = gy == 0 ? 1.0 : -gy.sign;
  } else {
    // Flat-ish: Z closest to up (screen up/down).
    magRad = math.atan2(math.sqrt(gx * gx + gy * gy), absZ);
    sign = gx == 0 ? 1.0 : -gx.sign;
  }

  return clampLeanDegrees(sign * magRad * 180 / math.pi);
}
