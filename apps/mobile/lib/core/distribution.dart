/// Build-time distribution channel.
///
/// Play Store AAB:
///   flutter build appbundle --flavor play --dart-define=DISTRIBUTION=play
///
/// GitHub sideload APK (friend builds):
///   flutter build apk --flavor sideload --dart-define=DISTRIBUTION=sideload
class AppDistribution {
  AppDistribution._();

  static const channel = String.fromEnvironment(
    'DISTRIBUTION',
    defaultValue: 'sideload',
  );

  /// True when built for Google Play (no sideload APK installer).
  static bool get isPlayStore => channel == 'play';

  /// GitHub Release APK install path (REQUEST_INSTALL_PACKAGES).
  static bool get allowsSideloadUpdates => !isPlayStore;
}
