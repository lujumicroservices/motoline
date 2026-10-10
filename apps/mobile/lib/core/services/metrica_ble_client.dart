import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'metrica_ble_permissions.dart';
import 'metrica_ble_protocol.dart';

/// Scans, connects, and writes the Métrica pairing GATT.
///
/// Logs phase, MTU, byte counts, and [MetricaBleProtocol.statusLogLine] only.
/// Payloads (PIN, `secret`, Wi-Fi password) are never printed.
class MetricaBleClient implements MetricaBleTransport {
  MetricaBleClient({MetricaBlePermissions? permissions})
    : _permissions = permissions ?? const MetricaBlePermissions();

  final MetricaBlePermissions _permissions;
  final Map<String, BluetoothDevice> _seen = {};
  MetricaBleAccess? _access;

  @override
  Future<void> ensureReady() async {
    if (kIsWeb) {
      throw const MetricaBleException(MetricaBleFailure.unsupported);
    }
    final supported = await FlutterBluePlus.isSupported;
    if (!supported) {
      throw const MetricaBleException(MetricaBleFailure.unsupported);
    }
    _access = await _permissions.ensure();
    await _ensureAdapterOn();
  }

  @override
  Future<List<MetricaScanHit>> scan({required Duration timeout}) async {
    final access = _access ?? await _readyAccess();
    await FlutterBluePlus.stopScan();
    // Merge ADV + scan-response fields across callbacks for the same device.
    final names = <String, String>{};
    final uuids = <String, Set<String>>{};
    final rssi = <String, int>{};
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final id = result.device.remoteId.str;
        _seen[id] = result.device;
        rssi[id] = result.rssi;
        final name = MetricaBleProtocol.bestAdvertisedName(
          advName: result.advertisementData.advName,
          platformName: result.device.platformName,
        );
        if (name.isNotEmpty) {
          final prev = names[id];
          if (prev == null ||
              MetricaBleProtocol.canonicalizeAdvertisedName(name) != null) {
            names[id] = name;
          }
        }
        final found = uuids.putIfAbsent(id, () => <String>{});
        for (final guid in result.advertisementData.serviceUuids) {
          found.add(guid.str128);
        }
        for (final guid in result.advertisementData.serviceData.keys) {
          found.add(guid.str128);
        }
      }
    });
    try {
      // No withServices filter: Android ScanFilter often misses a 128-bit UUID
      // that only appears in the scan response. Filter in software after merge.
      //
      // Important: `startScan` completes when the scan *starts*, not when the
      // timeout ends. Waiting here is required; stopping in `finally` without
      // a delay aborts the scan in ~0–1 s (empty hits every time).
      await FlutterBluePlus.startScan(
        timeout: timeout,
        continuousUpdates: true,
        androidUsesFineLocation: access.usesFineLocation,
        androidCheckLocationServices: access.usesFineLocation,
      );
      await Future.any([
        FlutterBluePlus.isScanning.where((scanning) => !scanning).first,
        Future<void>.delayed(timeout + const Duration(milliseconds: 400)),
      ]);
    } catch (error) {
      throw _mapBleError(error);
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }
    final hits = <MetricaScanHit>[];
    for (final id in rssi.keys) {
      final name = names[id] ?? '';
      final serviceUuids = uuids[id] ?? const <String>{};
      if (!MetricaBleProtocol.matchesAdvertisement(
        name: name,
        serviceUuidStrings: serviceUuids,
      )) {
        continue;
      }
      final label =
          MetricaBleProtocol.canonicalizeAdvertisedName(name) ??
          (name.isNotEmpty ? name : 'Metrica');
      hits.add(
        MetricaScanHit(remoteId: id, name: label, rssi: rssi[id] ?? -100),
      );
    }
    hits.sort((a, b) => b.rssi.compareTo(a.rssi));
    debugPrint(
      'metrica_ble: scan seen=${rssi.length} hits=${hits.length} '
      'names=${names.values.where((n) => n.isNotEmpty).take(8).join(",")}',
    );
    return hits;
  }

  @override
  Future<MetricaGattLink> connect(MetricaScanHit device) async {
    await _ensureAdapterOn();
    final remote =
        _seen[device.remoteId] ?? BluetoothDevice.fromId(device.remoteId);
    try {
      await remote.connect(
        autoConnect: false,
        timeout: MetricaBleProtocol.connectTimeout,
        mtu: MetricaBleProtocol.requestedMtu,
      );
    } catch (error) {
      throw _mapBleError(error);
    }

    final mtu = await _requestMtu(remote);
    final maxWrite = MetricaBleProtocol.maxWriteLength(mtu);
    debugPrint('metrica_ble: connected mtu=$mtu maxWrite=$maxWrite');

    List<BluetoothService> services;
    try {
      services = await remote.discoverServices();
    } catch (error) {
      await _disconnectQuiet(remote);
      throw _mapBleError(error);
    }

    final service = _service(services, MetricaBleProtocol.serviceUuid);
    if (service == null) {
      await _disconnectQuiet(remote);
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    final info = _char(service, MetricaBleProtocol.infoUuid);
    final auth = _char(service, MetricaBleProtocol.authUuid);
    final pair = _char(service, MetricaBleProtocol.pairUuid);
    final wifi = _char(service, MetricaBleProtocol.wifiUuid);
    final status = _char(service, MetricaBleProtocol.statusUuid);
    if (info == null ||
        auth == null ||
        pair == null ||
        wifi == null ||
        status == null) {
      await _disconnectQuiet(remote);
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }

    final link = _MetricaBleLink(
      device: remote,
      info: info,
      auth: auth,
      pair: pair,
      wifi: wifi,
      status: status,
      maxWriteLength: maxWrite,
    );
    try {
      await link.subscribe();
    } catch (error) {
      await link.disconnect();
      throw _mapBleError(error);
    }
    return link;
  }

  Future<MetricaBleAccess> _readyAccess() async {
    await ensureReady();
    return _access!;
  }

  Future<void> _ensureAdapterOn() async {
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) return;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (_) {
        debugPrint('metrica_ble: turnOn failed');
      }
    }
    try {
      await FlutterBluePlus.adapterState
          .firstWhere((state) => state == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw const MetricaBleException(MetricaBleFailure.bluetoothOff);
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      throw const MetricaBleException(MetricaBleFailure.bluetoothOff);
    }
  }

  Future<int> _requestMtu(BluetoothDevice device) async {
    final current = device.mtuNow;
    if (current >= MetricaBleProtocol.requestedMtu) return current;
    try {
      final negotiated = await device.requestMtu(
        MetricaBleProtocol.requestedMtu,
      );
      if (negotiated >= 23) return negotiated;
    } catch (_) {
      debugPrint('metrica_ble: mtu request failed');
    }
    final after = device.mtuNow;
    return after >= 23 ? after : 23;
  }

  BluetoothService? _service(List<BluetoothService> services, String uuid) {
    for (final service in services) {
      if (MetricaBleProtocol.sameUuid(service.uuid.str128, uuid)) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _char(BluetoothService service, String uuid) {
    for (final characteristic in service.characteristics) {
      if (MetricaBleProtocol.sameUuid(characteristic.uuid.str128, uuid)) {
        return characteristic;
      }
    }
    return null;
  }

  Future<void> _disconnectQuiet(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {}
  }
}

class _MetricaBleLink implements MetricaGattLink {
  _MetricaBleLink({
    required this.device,
    required this.info,
    required this.auth,
    required this.pair,
    required this.wifi,
    required this.status,
    required this.maxWriteLength,
  });

  final BluetoothDevice device;
  final BluetoothCharacteristic info;
  final BluetoothCharacteristic auth;
  final BluetoothCharacteristic pair;
  final BluetoothCharacteristic wifi;
  final BluetoothCharacteristic status;

  @override
  final int maxWriteLength;

  final _reassembler = MetricaReassembler();
  final _statuses = StreamController<MetricaStatus>.broadcast();
  StreamSubscription<List<int>>? _statusSub;

  /// Must run before any write. The initial value is `{"ok":true,"msg":"ready"}`
  /// and NimBLE notifies it on subscribe; [_nextStatus] ignores that `ready`.
  Future<void> subscribe() async {
    _statusSub = status.onValueReceived.listen(_onStatus);
    final notify = status.properties.notify || status.properties.indicate;
    if (!notify) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    await status.setNotifyValue(true);
  }

  void _onStatus(List<int> value) {
    final message = _reassembler.add(value);
    if (message == null) return;
    try {
      final parsed = MetricaBleProtocol.parseStatus(message);
      debugPrint('metrica_ble: ${MetricaBleProtocol.statusLogLine(parsed)}');
      if (!_statuses.isClosed) _statuses.add(parsed);
    } catch (_) {
      debugPrint('metrica_ble: status parse failed');
    }
  }

  @override
  Future<MetricaDeviceInfo> readInfo() async {
    try {
      final bytes = await info.read();
      return MetricaBleProtocol.parseInfo(bytes);
    } on MetricaBleException {
      rethrow;
    } catch (error) {
      if (error is FormatException) {
        throw const MetricaBleException(MetricaBleFailure.protocol);
      }
      throw _mapBleError(error);
    }
  }

  @override
  Future<MetricaStatus> writeAuth(List<int> pinBytes) {
    return _write(auth, pinBytes, label: 'auth');
  }

  @override
  Future<MetricaStatus> writePair(List<int> payload) {
    return _write(pair, payload, label: 'pair');
  }

  @override
  Future<MetricaStatus> writeWifi(List<int> payload) {
    return _write(wifi, payload, label: 'wifi');
  }

  Future<MetricaStatus> _write(
    BluetoothCharacteristic characteristic,
    List<int> payload, {
    required String label,
  }) async {
    final frames = MetricaBleProtocol.encodeWrite(
      payload,
      maxChunk: maxWriteLength,
    );
    debugPrint(
      'metrica_ble: write $label bytes=${payload.length} frames=${frames.length}',
    );
    final pending = _nextStatus();
    try {
      final withResponse = characteristic.properties.write;
      if (!withResponse && !characteristic.properties.writeWithoutResponse) {
        throw const MetricaBleException(MetricaBleFailure.protocol);
      }
      for (final frame in frames) {
        await characteristic.write(
          frame,
          withoutResponse: !withResponse,
          allowLongWrite: false,
        );
      }
      return await pending;
    } catch (error) {
      unawaited(pending.then((_) {}, onError: (_) {}));
      if (error is MetricaBleException) rethrow;
      throw _mapBleError(error);
    }
  }

  Future<MetricaStatus> _nextStatus() async {
    final deadline = DateTime.now().add(MetricaBleProtocol.statusTimeout);
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw const MetricaBleException(MetricaBleFailure.timeout);
      }
      final status = await _statuses.stream.first.timeout(
        remaining,
        onTimeout: () =>
            throw const MetricaBleException(MetricaBleFailure.timeout),
      );
      // Initial notify on subscribe. A write never answers `ready`.
      if (status.ok && status.msg == 'ready') {
        debugPrint('metrica_ble: ignore initial ready');
        continue;
      }
      return status;
    }
  }

  @override
  Future<void> disconnect() async {
    await _statusSub?.cancel();
    _statusSub = null;
    if (!_statuses.isClosed) await _statuses.close();
    try {
      await device.disconnect();
    } catch (_) {}
  }
}

MetricaBleException _mapBleError(Object error) {
  if (error is MetricaBleException) return error;
  final text = error.toString().toLowerCase();
  if (text.contains('timeout') || text.contains('timed out')) {
    return const MetricaBleException(MetricaBleFailure.timeout);
  }
  if (text.contains('location')) {
    return const MetricaBleException(MetricaBleFailure.locationDenied);
  }
  if (text.contains('permission') || text.contains('denied')) {
    return const MetricaBleException(MetricaBleFailure.permissionDenied);
  }
  if (text.contains('off') || text.contains('adapter')) {
    return const MetricaBleException(MetricaBleFailure.bluetoothOff);
  }
  return const MetricaBleException(MetricaBleFailure.connectFailed);
}
