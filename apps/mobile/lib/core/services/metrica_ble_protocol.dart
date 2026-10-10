import 'dart:convert';

/// GATT contract for pairing a Métrica logger (firmware 0.6.8-ble).
///
/// UUIDs and the STATUS `code` strings below are the single place the app
/// knows them. They are provisional until that firmware build publishes the
/// final values — replace this block, not the call sites.
///
/// Advertisement:
/// - Complete local name `Metrica-XXXX` (exactly four alphanumeric characters).
/// - This service UUID is also advertised.
///
/// Characteristics:
/// - [infoUuid] read. JSON. Version (`fw`, `v`, `version`, or `firmware`),
///   paired (`paired` or `is_paired`), pairing mode (`pairing`,
///   `pairing_mode`, or `in_pairing`).
/// - [authUuid] write. The 6-digit PIN as UTF-8 text, not JSON.
///   Without a successful AUTH the logger rejects every other write.
///   After 5 failed PINs it leaves pairing mode.
/// - [pairUuid] write. JSON `{"device_id","secret","ingest_url"}`.
/// - [wifiUuid] write. JSON `{"ssid","pass"}`. Optional.
/// - [statusUuid] notify. JSON `{"ok":bool,"code":str,"msg":str}`.
///
/// The phone requests ATT MTU 517. A write that fits in `MTU - 3` is sent
/// raw (JSON starts with `{`, a PIN with a digit). Otherwise it is split:
///
/// ```text
/// byte 0: 0xF1
/// byte 1: seq   (uint8, 0-based)
/// byte 2: count (uint8, >= 2)
/// byte 3..: slice
/// ```
///
/// The logger concatenates slices in `seq` order and parses the payload once
/// every index `0 .. count-1` has arrived. A STATUS notification may use the
/// same frame. A value that does not start with `0xF1` is a complete message.
///
/// `secret` and the Wi-Fi password are never put in logs or in [toString].
abstract final class MetricaBleProtocol {
  /// Provisional primary service. Firmware 0.6.8-ble owns the real value.
  static const serviceUuid = '8f3a1c20-6b4e-4d91-9c17-5e2b7a4d6f10';

  static const infoUuid = '8f3a1c21-6b4e-4d91-9c17-5e2b7a4d6f10';
  static const authUuid = '8f3a1c22-6b4e-4d91-9c17-5e2b7a4d6f10';
  static const pairUuid = '8f3a1c23-6b4e-4d91-9c17-5e2b7a4d6f10';
  static const wifiUuid = '8f3a1c24-6b4e-4d91-9c17-5e2b7a4d6f10';
  static const statusUuid = '8f3a1c25-6b4e-4d91-9c17-5e2b7a4d6f10';

  /// Leading byte of a fragmented write or notification. Never a JSON or PIN.
  static const fragmentMagic = 0xF1;

  static const fragmentHeaderLength = 3;

  static const requestedMtu = 517;

  /// How long the phone waits for one STATUS notification.
  static const statusTimeout = Duration(seconds: 8);

  static const scanTimeout = Duration(seconds: 12);

  static const connectTimeout = Duration(seconds: 15);

  /// Canonical advertisement name, e.g. `Metrica-A1B2`.
  static final advertisedName = RegExp(r'^Metrica-[A-Za-z0-9]{4}$');

  static final pinPattern = RegExp(r'^\d{6}$');

  /// STATUS `code` values treated as a rejected PIN.
  ///
  /// Provisional. Add the firmware's exact code here when it lands.
  static const pinInvalidCodes = <String>{
    'pin_invalid',
    'bad_pin',
    'wrong_pin',
    'auth_failed',
    'pin_rejected',
  };

  /// STATUS `code` values meaning pairing mode closed after too many PINs.
  static const pinLockedCodes = <String>{
    'pin_locked',
    'locked',
    'pairing_closed',
    'too_many_pin',
    'auth_locked',
  };

  static const timeoutCodes = <String>{'timeout', 'timed_out'};

  static int maxWriteLength(int mtu) {
    final att = mtu < 23 ? 23 : mtu;
    return att - 3;
  }

  static bool sameUuid(String a, String b) {
    String norm(String value) => value.toLowerCase().replaceAll('-', '').trim();
    return norm(a) == norm(b);
  }

  static String bestAdvertisedName({
    required String advName,
    required String platformName,
  }) {
    final adv = advName.trim();
    if (advertisedName.hasMatch(adv)) return adv;
    return platformName.trim();
  }

  /// Both the `Metrica-XXXX` name and the service UUID are required.
  static bool matchesAdvertisement({
    required String name,
    required Iterable<String> serviceUuidStrings,
  }) {
    if (!advertisedName.hasMatch(name.trim())) return false;
    return serviceUuidStrings.any((uuid) => sameUuid(uuid, serviceUuid));
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

  /// One ATT write per frame. The first frame is raw when [payload] fits.
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
      firmware: _string(map, const ['fw', 'v', 'version', 'firmware']),
      paired: _bool(map, const ['paired', 'is_paired']),
      pairingMode: _bool(map, const ['pairing', 'pairing_mode', 'in_pairing']),
    );
  }

  static MetricaStatus parseStatus(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('status');
    }
    final map = decoded.map((key, value) => MapEntry(key.toString(), value));
    final message = _string(map, const ['msg', 'message']);
    return MetricaStatus(
      ok: map['ok'] == true,
      code: _string(map, const ['code']),
      message: message,
    );
  }

  /// Log line for a STATUS notification. The human [MetricaStatus.message]
  /// is omitted so a firmware echo of `secret` cannot land in logcat.
  static String statusLogLine(MetricaStatus status) =>
      'ok=${status.ok} code=${status.code}';

  static String redact(String text, Iterable<String> secrets) {
    var out = text;
    final sorted = secrets.where((secret) => secret.length >= 4).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final secret in sorted) {
      out = out.replaceAll(secret, '***');
    }
    return out;
  }

  /// Accepts `ok: true`. Otherwise classifies PIN, lock, and timeout codes.
  static void requireAccepted(MetricaStatus status) {
    if (status.ok) return;
    final code = status.code.trim().toLowerCase();
    if (pinLockedCodes.contains(code)) {
      throw MetricaBleException(
        MetricaBleFailure.pinLocked,
        detail: status.message,
      );
    }
    if (pinInvalidCodes.contains(code)) {
      throw MetricaBleException(
        MetricaBleFailure.wrongPin,
        detail: status.message,
      );
    }
    if (timeoutCodes.contains(code)) {
      throw const MetricaBleException(MetricaBleFailure.timeout);
    }
    final detail = status.message.trim().isEmpty
        ? status.code.trim()
        : status.message.trim();
    throw MetricaBleException(
      MetricaBleFailure.protocol,
      detail: detail.isEmpty ? null : detail,
    );
  }

  static String _string(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String) return value.trim();
      if (value is num) return value.toString();
    }
    return '';
  }

  static bool? _bool(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final text = value.trim().toLowerCase();
        if (text == 'true' || text == '1' || text == 'yes') return true;
        if (text == 'false' || text == '0' || text == 'no') return false;
      }
    }
    return null;
  }
}

/// Reassembles fragmented STATUS notifications. A raw JSON value is returned
/// immediately. See [MetricaBleProtocol.fragmentMagic].
class MetricaReassembler {
  int? _count;
  final Map<int, List<int>> _parts = {};

  List<int>? add(List<int> frame) {
    if (frame.isEmpty) return null;
    if (frame[0] != MetricaBleProtocol.fragmentMagic) {
      _clear();
      return List<int>.from(frame);
    }
    if (frame.length < MetricaBleProtocol.fragmentHeaderLength) return null;
    final seq = frame[1];
    final count = frame[2];
    if (count < 2 || seq >= count) {
      _clear();
      return null;
    }
    if (_count != null && _count != count) _clear();
    _count = count;
    _parts[seq] = List<int>.from(frame.sublist(3));
    if (_parts.length < count) return null;
    for (var i = 0; i < count; i++) {
      if (!_parts.containsKey(i)) return null;
    }
    final out = <int>[];
    for (var i = 0; i < count; i++) {
      out.addAll(_parts[i]!);
    }
    _clear();
    return out;
  }

  void _clear() {
    _count = null;
    _parts.clear();
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
    required this.firmware,
    required this.paired,
    required this.pairingMode,
  });

  final String firmware;
  final bool? paired;
  final bool? pairingMode;
}

class MetricaStatus {
  const MetricaStatus({
    required this.ok,
    required this.code,
    required this.message,
  });

  final bool ok;
  final String code;
  final String message;

  MetricaStatus redact(Iterable<String> secrets) {
    return MetricaStatus(
      ok: ok,
      code: code,
      message: MetricaBleProtocol.redact(message, secrets),
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
  const MetricaBleException(this.failure, {this.detail});

  final MetricaBleFailure failure;

  /// Safe to show. Must already be redacted. Omitted from [toString].
  final String? detail;

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
