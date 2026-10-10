import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'distribution.dart';

/// Installed app identity — version, channel, optional experimental label.
class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.channel,
    required this.label,
  });

  final String version;
  final String buildNumber;
  final String channel;

  /// Set at build time, e.g. `--dart-define=BUILD_LABEL=exp-gps-track-points`.
  final String label;

  String get shortLine => 'RiderLab $version ($buildNumber)';

  String get fullLine {
    final parts = <String>[shortLine, channel];
    if (label.isNotEmpty) parts.add(label);
    return parts.join(' · ');
  }

  bool get isExperimental => label.isNotEmpty;
}

final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final pkg = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    version: pkg.version,
    buildNumber: pkg.buildNumber,
    channel: AppDistribution.channel,
    label: const String.fromEnvironment('BUILD_LABEL', defaultValue: ''),
  );
});
