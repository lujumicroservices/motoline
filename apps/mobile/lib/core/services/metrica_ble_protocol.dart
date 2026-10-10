import 'dart:convert';

/// GATT contract for pairing a Métrica logger (firmware 0.6.8-ble).
///
/// Advertising name `Metrica-XXXX`: XXXX is the last two bytes of the Wi-Fi
/// STA MAC in uppercase hex (for example `76:38` → `Metrica-7638`). The BLE
/// address is the base MAC + 2; do not derive the name from it. The service
/// UUID is often in the advertisement and the name in the scan response —
/// match either field; do not require both on one callback.
///
/// Characteristics (suffix `5c3e-4b8e-9a51-4d4554524943`):
/// - [infoUuid] read. JSON `fw`, `paired`, `device_id`, `wifi`, `authed`, `mtu`.
/// - [authUuid] write with response. Six ASCII digits. Per connection.
/// - [pairUuid] write with response, max 600 B.
///   JSON `{"device_id","secret","ingest_url"}`.
/// - [wifiUuid] write with response, max 600 B. JSON `{"ssid","pass"}`.
///   Send this before PAIR: after `paired` the logger closes the mode in ~3 s.
/// - [statusUuid] read + notify. One answer per write.
///   `{"ok":true,"msg":"ready|auth_ok|paired|wifi_saved"}` or
///   `{"ok":false,"err":"bad_pin","left":N}` and
///   `auth_required|bad_json|missing_fields|bad_fields`.
///   `bad_pin` with `left` 0 closes pairing mode.
///
/// Subscribe to STATUS before any write. Write, wait for that STATUS, then
/// write the next value. The phone requests ATT MTU 247. A payload that fits
/// in `mtu - 3` is written raw. Otherwise each fragment is
/// `[0x1E][index][total][bytes]` and carries `mtu - 6` payload bytes.
///
/// `secret` and the Wi-Fi password are never put in logs or in [toString].
abstract final class MetricaBleProtocol {
  static const _uuidSuffix = '5c3e-4b8e-9a51-4d4554524943';

  static const serviceUuid = '6f8a0001-$_uuidSuffix';
  static const infoUuid = '6f8a0002-$_uuidSuffix';
  static const authUuid = '6f8a0003-$_uuidSuffix';
  static const pairUuid = '6f8a0004-$_uuidSuffix';
  static const wifiUuid = '6f8a0005-$_uuidSuffix';
  static const statusUuid = '6f8a0006-$_uuidSuffix';

  /// Leading byte of a fragmented write or notification.
  static const fragmentMagic = 0x1E;

  static const fragmentHeaderLength = 3;

  /// ATT MTU the app requests. Android usually negotiates 185–247.
  static const requestedMtu = 247;

  /// How long the phone waits for one STATUS notification.
  static const statusTimeout = Duration(seconds: 8);

  static const scanTimeout = Duration(seconds: 12);

  static const connectTimeout = Duration(seconds: 15);

  /// Canonical advertisement name, e.g. `Metrica-7638`.
  /// Case-insensitive: some stacks lower-case the ADV / scan-response name.
  static final advertisedName = RegExp(
    r'^Metrica-[0-9A-Fa-f]{4}$',
    caseSensitive: false,
  );

  static final pinPattern = RegExp(r'^\d{6}$');

  static const okMessages = <String>{
    'ready',
    'auth_ok',
    'paired',
    'wifi_saved',
  };

  static const errorCodes = <String>{
    'bad_pin',
    'auth_required',
    'bad_json',
    'missing_fields',
    'bad_fields',
  };

  /// ATT payload per write: MTU − 3.
  static int maxWriteLength(int mtu) {
    final att = mtu < 23 ? 23 : mtu;
    return att - 3;
  }

  /// JSON bytes inside one fragment: MTU − 6 (header is 3 bytes).
  static int fragmentDataLength(int mtu) {
    final room = maxWriteLength(mtu) - fragmentHeaderLength;
    if (room < 1) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    return room;
  }

  static bool sameUuid(String a, String b) {
    String norm(String value) => value.toLowerCase().replaceAll('-', '').trim();
    return norm(a) == norm(b);
  }

  /// Prefer a `Metrica-XXXX` name; normalize hex to uppercase.
  static String bestAdvertisedName({
    required String advName,
    required String platformName,
  }) {
    final adv = canonicalizeAdvertisedName(advName);
    if (adv != null) return adv;
    final platform = canonicalizeAdvertisedName(platformName);
    if (platform != null) return platform;
    final fallback = platformName.trim();
    return fallback.isNotEmpty ? fallback : advName.trim();
  }

  static String? canonicalizeAdvertisedName(String raw) {
    final trimmed = raw.trim();
    if (!advertisedName.hasMatch(trimmed)) return null;
    final dash = trimmed.indexOf('-');
    if (dash < 0 || dash + 5 > trimmed.length) return null;
    return 'Metrica-${trimmed.substring(dash + 1).toUpperCase()}';
  }

  static bool hasServiceUuid(Iterable<String> serviceUuidStrings) {
    return serviceUuidStrings.any((uuid) => sameUuid(uuid, serviceUuid));
  }

  /// Accept name **or** service UUID.
  ///
  /// Android often delivers the 128-bit UUID in the ADV packet and the
  /// `Metrica-XXXX` name in the scan response (or the reverse). Requiring both
  /// on a single callback drops every hit.
  static bool matchesAdvertisement({
    required String name,
    required Iterable<String> serviceUuidStrings,
  }) {
    final named = advertisedName.hasMatch(name.trim());
    final uuid = hasServiceUuid(serviceUuidStrings);
    return named || uuid;
  }

  static void validatePin(String pin) {
    if (!pinPattern.hasMatch(pin)) {
      throw const MetricaBleException(MetricaBleFailure.pinFormat);
    }
  }

  static List<int> authBytes(String pin) {
    validatePin(pin);
    return utf8.encode(pin);
  }

  static List<int> pairPayload({
    required String deviceId,
    required String secret,
    required String ingestUrl,
  }) {
    return utf8.encode(
      jsonEncode({
        'device_id': deviceId,
        'secret': secret,
        'ingest_url': ingestUrl,
      }),
    );
  }

  static List<int> wifiPayload({required String ssid, required String pass}) {
    return utf8.encode(jsonEncode({'ssid': ssid, 'pass': pass}));
  }

  /// One ATT write per frame. The first frame is raw when [payload] fits
  /// in [maxChunk] (`mtu - 3`). Otherwise each frame is
  /// `[0x1E, index, total, ...slice]` and [slice] is `mtu - 6` bytes.
  static List<List<int>> encodeWrite(
    List<int> payload, {
    required int maxChunk,
  }) {
    if (payload.isEmpty || maxChunk < 1) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    if (payload.length <= maxChunk) {
      return [List<int>.from(payload)];
    }
    if (maxChunk <= fragmentHeaderLength) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    final slice = maxChunk - fragmentHeaderLength;
    final count = (payload.length + slice - 1) ~/ slice;
    if (count > 255) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    final frames = <List<int>>[];
    for (var i = 0; i < count; i++) {
      final start = i * slice;
      final end = start + slice < payload.length
          ? start + slice
          : payload.length;
      frames.add([fragmentMagic, i, count, ...payload.sublist(start, end)]);
    }
    return frames;
  }

  static MetricaDeviceInfo parseInfo(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('info');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    return MetricaDeviceInfo(
      hw: _string(map, 'hw'),
      firmware: _string(map, 'fw'),
      role: _string(map, 'role'),
      paired: _bool(map, 'paired'),
      deviceId: _string(map, 'device_id'),
      wifi: _bool(map, 'wifi'),
      authed: _bool(map, 'authed'),
      mtu: _int(map, 'mtu'),
    );
  }

  static MetricaStatus parseStatus(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('status');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    return MetricaStatus(
      ok: map['ok'] == true,
      msg: _string(map, 'msg'),
      err: _string(map, 'err'),
      left: _int(map, 'left'),
    );
  }

  /// Log line for a STATUS notification. Only the known short codes are
  /// printed, so a firmware echo of `secret` cannot land in logcat.
  static String statusLogLine(MetricaStatus status) {
    if (status.ok) {
      final msg = okMessages.contains(status.msg) ? status.msg : 'unlisted';
      return 'ok=true msg=$msg';
    }
    final err = errorCodes.contains(status.err) ? status.err : 'unlisted';
    final left = status.left == null ? '' : ' left=${status.left}';
    return 'ok=false err=$err$left';
  }

  static String redact(String text, Iterable<String> secrets) {
    var out = text;
    final sorted = secrets.where((secret) => secret.length >= 4).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final secret in sorted) {
      out = out.replaceAll(secret, '***');
    }
    return out;
  }

  /// Accepts `ok: true`. `bad_pin` with no attempts left closes the mode.
  static void requireAccepted(MetricaStatus status) {
    if (status.ok) return;
    final err = status.err.trim();
    if (err == 'bad_pin') {
      final left = status.left;
      if (left == null || left <= 0) {
        throw MetricaBleException(
          MetricaBleFailure.pinLocked,
          attemptsLeft: left,
        );
      }
      throw MetricaBleException(MetricaBleFailure.wrongPin, attemptsLeft: left);
    }
    if (errorCodes.contains(err)) {
      throw MetricaBleException(MetricaBleFailure.protocol, detail: err);
    }
    throw const MetricaBleException(MetricaBleFailure.protocol);
  }

  /// [requireAccepted], then the success `msg` the write was waiting for.
  static void requireMsg(MetricaStatus status, String msg) {
    requireAccepted(status);
    if (status.msg != msg) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String) return value.trim();
    if (value is num) return value.toString();
    return '';
  }

  static bool? _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 'yes') return true;
      if (text == 'false' || text == '0' || text == 'no') return false;
    }
    return null;
  }

  static int? _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

/// Reassembles fragmented STATUS notifications.
///
/// A value that does not start with [MetricaBleProtocol.fragmentMagic] is a
/// complete message. Index 0 restarts reassembly. An out-of-order index
/// drops the buffer and yields nothing (the firmware sends no STATUS).
class MetricaReassembler {
  int? _total;
  int _next = 0;
  final List<int> _buffer = [];

  List<int>? add(List<int> frame) {
    if (frame.isEmpty) return null;
    if (frame[0] != MetricaBleProtocol.fragmentMagic) {
      _reset();
      return List<int>.from(frame);
    }
    if (frame.length < MetricaBleProtocol.fragmentHeaderLength) return null;
    final index = frame[1];
    final total = frame[2];
    if (total < 1 || index >= total) {
      _reset();
      return null;
    }
    if (index == 0) {
      _reset();
      _total = total;
      _buffer.addAll(frame.sublist(3));
      _next = 1;
    } else if (_total != total || index != _next) {
      _reset();
      return null;
    } else {
      _buffer.addAll(frame.sublist(3));
      _next = index + 1;
    }
    if (_total == null || _next < _total!) return null;
    final out = List<int>.from(_buffer);
    _reset();
    return out;
  }

  void _reset() {
    _total = null;
    _next = 0;
    _buffer.clear();
  }
}

class MetricaScanHit {
  const MetricaScanHit({
    required this.remoteId,
    required this.name,
    required this.rssi,
  });

  final String remoteId;
  final String name;
  final int rssi;
}

class MetricaDeviceInfo {
  const MetricaDeviceInfo({
    this.hw = '',
    this.firmware = '',
    this.role = '',
    this.paired,
    this.deviceId = '',
    this.wifi,
    this.authed,
    this.mtu,
  });

  final String hw;
  final String firmware;
  final String role;
  final bool? paired;
  final String deviceId;
  final bool? wifi;
  final bool? authed;
  final int? mtu;
}

class MetricaStatus {
  const MetricaStatus({
    required this.ok,
    this.msg = '',
    this.err = '',
    this.left,
  });

  final bool ok;
  final String msg;
  final String err;
  final int? left;

  MetricaStatus redact(Iterable<String> secrets) {
    return MetricaStatus(
      ok: ok,
      msg: MetricaBleProtocol.redact(msg, secrets),
      err: MetricaBleProtocol.redact(err, secrets),
      left: left,
    );
  }
}

enum MetricaBleFailure {
  bluetoothOff,
  unsupported,
  permissionDenied,
  locationDenied,
  notFound,
  wrongPin,
  pinFormat,
  pinLocked,
  timeout,
  noSession,
  connectFailed,
  protocol,
  wifiRejected,
  cancelled,
}

class MetricaBleException implements Exception {
  const MetricaBleException(this.failure, {this.detail, this.attemptsLeft});

  final MetricaBleFailure failure;

  /// Safe to show. Must already be redacted. Omitted from [toString].
  final String? detail;

  /// Attempts still left after `bad_pin`. Zero means the mode closed.
  final int? attemptsLeft;

  factory MetricaBleException.fromPairingService(StateError error) {
    final message = error.message.toLowerCase();
    if (message.contains('not signed') ||
        message.contains('not ready') ||
        message.contains('sign in')) {
      return const MetricaBleException(MetricaBleFailure.noSession);
    }
    if (message.startsWith('mint failed')) {
      return const MetricaBleException(
        MetricaBleFailure.protocol,
        detail: 'mint failed',
      );
    }
    if (message.startsWith('claim failed')) {
      return const MetricaBleException(
        MetricaBleFailure.protocol,
        detail: 'claim failed',
      );
    }
    return const MetricaBleException(MetricaBleFailure.protocol);
  }

  /// Does not include [detail], which can carry a device STATUS message.
  @override
  String toString() => 'MetricaBleException(${failure.name})';
}

class MetricaPairSuccess {
  const MetricaPairSuccess({required this.deviceId, required this.status});

  final String deviceId;
  final MetricaStatus status;

  @override
  String toString() => 'MetricaPairSuccess($deviceId)';
}

class MetricaWifiCredentials {
  const MetricaWifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;
}

enum MetricaPairPhase { auth, mint, write, wifi }

/// Open GATT session. Implementations must not log write payloads.
abstract class MetricaGattLink {
  int get maxWriteLength;

  Future<MetricaDeviceInfo> readInfo();

  Future<MetricaStatus> writeAuth(List<int> pinBytes);

  Future<MetricaStatus> writePair(List<int> payload);

  Future<MetricaStatus> writeWifi(List<int> payload);

  Future<void> disconnect();
}

abstract class MetricaBleTransport {
  Future<void> ensureReady();

  Future<List<MetricaScanHit>> scan({required Duration timeout});

  Future<MetricaGattLink> connect(MetricaScanHit device);
}
