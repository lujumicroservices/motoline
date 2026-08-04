import '../core/services/location_service.dart';
import 'app_localizations.dart';

extension GpsWarmupL10n on AppLocalizations {
  String gpsWarmupStatusText(GnssWarmupStatus status) {
    final acc = status.accuracyMeters;
    final meters = acc != null && acc > 0 ? acc.toStringAsFixed(0) : null;
    return switch (status.phase) {
      GpsWarmupPhase.permissions => gpsCheckingPermission,
      GpsWarmupPhase.searching => gpsLookingSatellites,
      GpsWarmupPhase.locking =>
        meters == null ? gpsWarming : gpsWarmingAcc(meters),
      GpsWarmupPhase.ready =>
        meters == null ? gpsReady : gpsReadyAcc(meters),
      GpsWarmupPhase.timeout => meters == null
          ? gpsStartKeepSky
          : gpsStartWithAcc(meters),
    };
  }

  String locationDeniedText(LocationPermissionDenyReason reason) {
    return switch (reason) {
      LocationPermissionDenyReason.servicesOff => locationServicesOff,
      LocationPermissionDenyReason.denied => locationPermissionDenied,
      LocationPermissionDenyReason.deniedForever =>
        locationPermissionDeniedForever,
    };
  }

  String userFacingError(Object error) {
    if (error is LocationDeniedException) {
      return locationDeniedText(error.reason);
    }
    final text = '$error';
    if (text.contains('Rolling to next lap')) return gpsRollingNextLap;
    return text;
  }
}
