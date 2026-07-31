import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.tagName,
    required this.version,
    required this.apkUrl,
    required this.apkName,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.currentVersion,
    required this.currentBuild,
  });

  final String tagName;
  final String version;
  final String apkUrl;
  final String apkName;
  final String releaseNotes;
  final String releaseUrl;
  final String currentVersion;
  final String currentBuild;

  String get title => 'RiderLab $version';
}

/// Checks GitHub Releases for a newer APK and installs it (Android sideload).
class AppUpdateService {
  AppUpdateService({
    this.owner = 'lujumicroservices',
    this.repo = 'motoline',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String owner;
  final String repo;
  final http.Client _client;

  Uri get _latestReleaseUri =>
      Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid) return null;

    final package = await PackageInfo.fromPlatform();
    final response = await _client.get(
      _latestReleaseUri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Update check failed (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?)?.trim() ?? '';
    final remoteVersion = normalizeVersion(tag);
    final localVersion = normalizeVersion(package.version);
    if (!isNewer(remoteVersion, localVersion)) {
      return null;
    }

    final assets = (json['assets'] as List<dynamic>? ?? const []);
    Map<String, dynamic>? apk;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String?) ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        apk = asset;
        break;
      }
    }
    if (apk == null) {
      throw StateError('Latest release has no APK asset');
    }

    final url = apk['browser_download_url'] as String?;
    final name = apk['name'] as String?;
    if (url == null || name == null) {
      throw StateError('APK download URL missing');
    }

    return AppUpdateInfo(
      tagName: tag,
      version: remoteVersion,
      apkUrl: url,
      apkName: name,
      releaseNotes: (json['body'] as String?)?.trim() ?? '',
      releaseUrl: (json['html_url'] as String?) ?? '',
      currentVersion: localVersion,
      currentBuild: package.buildNumber,
    );
  }

  /// Downloads the APK and opens the system installer.
  Future<void> downloadAndInstall(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) {
      throw StateError('Updates are only supported on Android');
    }

    final installPerm = await Permission.requestInstallPackages.request();
    if (!installPerm.isGranted) {
      throw StateError(
        'Allow “Install unknown apps” for RiderLab to install updates.',
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, update.apkName));
    if (await file.exists()) {
      await file.delete();
    }

    final request = http.Request('GET', Uri.parse(update.apkUrl));
    final streamed = await _client.send(request);
    if (streamed.statusCode != 200) {
      throw StateError('Download failed (${streamed.statusCode})');
    }

    final total = streamed.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in streamed.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        onProgress?.call(received / total);
      }
    }
    await sink.close();

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError(result.message);
    }
  }

  static String normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    return v.split('+').first.split('-').first;
  }

  static bool isNewer(String remote, String local) {
    final r = _parts(remote);
    final l = _parts(local);
    final n = r.length > l.length ? r.length : l.length;
    for (var i = 0; i < n; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv > lv) return true;
      if (rv < lv) return false;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return version
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }
}
