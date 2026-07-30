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

    // Best-effort: request "always" for outdoor rides that leave the app.
    final always = await Permission.locationAlways.request();
    if (!always.isGranted &&
        permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return const LocationPermissionResult(
        granted: false,
        message: 'Location permission is required.',
      );
    }

    return const LocationPermissionResult(granted: true);
  }

  Stream<Position> watchPositions() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
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
