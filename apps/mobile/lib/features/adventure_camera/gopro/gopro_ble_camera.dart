import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../camera_controller.dart';
import '../models/adventure_camera_status.dart';
import 'gopro_uuids.dart';

/// Open GoPro BLE shutter control (experimental).
///
/// Soft-fails: connection/command errors surface via [status], never throw to
/// the ride recorder.
///
/// Cold cameras often wake on BLE connect but ignore an immediate shutter.
/// After attach we wait for boot, send keep-alive, then retry shutter writes.
class GoProBleCameraController implements AdventureCameraController {
  GoProBleCameraController()
      : _statusController =
            StreamController<AdventureCameraStatus>.broadcast();

  final StreamController<AdventureCameraStatus> _statusController;
  AdventureCameraStatus _status = const AdventureCameraStatus(
    phase: AdventureCameraPhase.idle,
  );

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandRequest;
  BluetoothCharacteristic? _settingsRequest;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _cmdRspSub;
  Timer? _keepAliveTimer;

  /// True after a successful attach that had to boot from a cold/asleep camera.
  /// Cleared after the first successful shutter (or disconnect).
  bool _needsColdStartGrace = false;

  /// Remote BLE id of the attached camera (for preferred reconnect).
  String? get remoteId => _device?.remoteId.str;

  @override
  String get backendId => 'gopro_ble';

  @override
  Stream<AdventureCameraStatus> get statusStream => _statusController.stream;

  @override
  AdventureCameraStatus get status => _status;

  @override
  Future<void> ensurePermissions() async {
    if (kIsWeb) {
      throw StateError('GoPro BLE is not supported on web');
    }
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      // Android ≤11 may only need location for legacy scan.
      final loc = await Permission.locationWhenInUse.request();
      if (!loc.isGranted && (!scan.isGranted || !connect.isGranted)) {
        throw StateError('Bluetooth permission denied');
      }
    }
    final adapterOn = await FlutterBluePlus.isSupported;
    if (!adapterOn) {
      throw StateError('Bluetooth LE not supported on this device');
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
  }

  @override
  Future<void> connect({String? preferredDeviceId}) async {
    try {
      await ensurePermissions();
      _emit(
        const AdventureCameraStatus(
          phase: AdventureCameraPhase.scanning,
          message: 'Scanning for GoPro…',
        ),
      );

      await _scanSub?.cancel();
      await FlutterBluePlus.stopScan();

      BluetoothDevice? found;
      final completer = Completer<BluetoothDevice?>();

      // Prefer reconnect by id when still bonded / in range.
      if (preferredDeviceId != null && preferredDeviceId.isNotEmpty) {
        try {
          final known = BluetoothDevice.fromId(preferredDeviceId);
          found = known;
        } catch (_) {}
      }

      if (found == null) {
        _scanSub = FlutterBluePlus.onScanResults.listen((results) {
          for (final r in results) {
            final name = r.device.platformName;
            final id = r.device.remoteId.str;
            final isGoPro = name.toLowerCase().contains('gopro');
            final isPreferred =
                preferredDeviceId != null && preferredDeviceId == id;
            if (isGoPro || isPreferred) {
              if (!completer.isCompleted) completer.complete(r.device);
              break;
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 12),
          androidUsesFineLocation: false,
          withServices: [Guid(GoProBleUuids.service)],
        );

        found = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => null,
        );
        await FlutterBluePlus.stopScan();
        await _scanSub?.cancel();
        _scanSub = null;
      }

      if (found == null) {
        _emit(
          const AdventureCameraStatus(
            phase: AdventureCameraPhase.error,
            message: 'No GoPro found — power on and open the side door',
          ),
        );
        return;
      }

      await _attach(found);
    } catch (e) {
      debugPrint('GoPro connect: $e');
      _emit(
        AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          message: '$e',
        ),
      );
    }
  }

  Future<void> _attach(BluetoothDevice device) async {
    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.connecting,
        deviceName: device.platformName.isEmpty
            ? 'GoPro'
            : device.platformName,
        message: 'Connecting…',
      ),
    );

    await _stopKeepAlive();
    await _cmdRspSub?.cancel();
    await _connSub?.cancel();
    _device = device;
    await device.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 20),
    );
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _commandRequest = null;
        _settingsRequest = null;
        unawaited(_stopKeepAlive());
        if (_status.phase == AdventureCameraPhase.recording ||
            _status.phase == AdventureCameraPhase.ready) {
          _emit(
            AdventureCameraStatus(
              phase: AdventureCameraPhase.idle,
              deviceName: _status.deviceName,
              message: 'GoPro disconnected',
            ),
          );
        }
      }
    });

    final services = await device.discoverServices();
    BluetoothCharacteristic? cmd;
    BluetoothCharacteristic? rsp;
    BluetoothCharacteristic? settings;
    BluetoothCharacteristic? settingsRsp;
    for (final s in services) {
      for (final c in s.characteristics) {
        final id = c.uuid.str128.toLowerCase();
        if (id == GoProBleUuids.commandRequest.toLowerCase()) {
          cmd = c;
        } else if (id == GoProBleUuids.commandResponse.toLowerCase()) {
          rsp = c;
        } else if (id == GoProBleUuids.settingsRequest.toLowerCase()) {
          settings = c;
        } else if (id == GoProBleUuids.settingsResponse.toLowerCase()) {
          settingsRsp = c;
        }
      }
    }

    if (cmd == null) {
      await device.disconnect();
      _emit(
        AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          deviceName: device.platformName,
          message: 'GoPro command characteristic missing (Open GoPro?)',
        ),
      );
      return;
    }

    _commandRequest = cmd;
    _settingsRequest = settings;

    if (rsp != null && rsp.properties.notify) {
      try {
        await rsp.setNotifyValue(true);
        await _cmdRspSub?.cancel();
        _cmdRspSub = rsp.onValueReceived.listen((_) {});
      } catch (e) {
        debugPrint('GoPro notify: $e');
      }
    }
    if (settingsRsp != null && settingsRsp.properties.notify) {
      try {
        await settingsRsp.setNotifyValue(true);
      } catch (e) {
        debugPrint('GoPro settings notify: $e');
      }
    }

    // Cold wake: BLE connect often powers the camera on, but the Open GoPro
    // command handler is not ready yet. Wait + keep-alive before claiming ready.
    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.connecting,
        deviceName: device.platformName.isEmpty
            ? 'GoPro'
            : device.platformName,
        message: 'Waking camera…',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    await _sendKeepAlive();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _needsColdStartGrace = true;
    _startKeepAlive();

    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.ready,
        deviceName: device.platformName.isEmpty
            ? 'GoPro'
            : device.platformName,
        message: 'Ready — will record with rides',
      ),
    );
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_sendKeepAlive());
    });
  }

  Future<void> _stopKeepAlive() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  Future<void> _sendKeepAlive() async {
    final settings = _settingsRequest;
    if (settings == null) return;
    try {
      await settings.write(GoProBleUuids.keepAlive, withoutResponse: false);
    } catch (e) {
      debugPrint('GoPro keep-alive: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      await FlutterBluePlus.stopScan();
      await _stopKeepAlive();
      await _cmdRspSub?.cancel();
      _cmdRspSub = null;
      await _connSub?.cancel();
      _connSub = null;
      _commandRequest = null;
      _settingsRequest = null;
      _needsColdStartGrace = false;
      final d = _device;
      _device = null;
      if (d != null) {
        await d.disconnect();
      }
    } catch (e) {
      debugPrint('GoPro disconnect: $e');
    }
    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.idle,
        deviceName: _status.deviceName,
      ),
    );
  }

  @override
  Future<void> startRecording() async {
    await _writeShutter(on: true, retries: _needsColdStartGrace ? 4 : 2);
  }

  @override
  Future<void> stopRecording() async {
    await _writeShutter(on: false, retries: 2);
  }

  Future<void> _writeShutter({required bool on, int retries = 2}) async {
    final cmd = _commandRequest;
    if (cmd == null) {
      _emit(
        AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          deviceName: _status.deviceName,
          message: 'GoPro not connected',
        ),
      );
      return;
    }

    Object? lastError;
    for (var attempt = 1; attempt <= retries; attempt++) {
      try {
        if (on && _needsColdStartGrace && attempt > 1) {
          await _sendKeepAlive();
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
        final bytes = on ? GoProBleUuids.shutterOn : GoProBleUuids.shutterOff;
        await cmd.write(bytes, withoutResponse: false);
        // Give the camera a beat to begin encoding after a cold wake.
        if (on && _needsColdStartGrace) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        if (on) _needsColdStartGrace = false;
        _emit(
          AdventureCameraStatus(
            phase: on
                ? AdventureCameraPhase.recording
                : AdventureCameraPhase.ready,
            deviceName: _status.deviceName,
            message: on ? 'Camera recording' : 'Camera idle',
          ),
        );
        return;
      } catch (e) {
        lastError = e;
        debugPrint('GoPro shutter attempt $attempt/$retries: $e');
        if (attempt < retries) {
          await Future<void>.delayed(
            Duration(milliseconds: 900 * attempt),
          );
        }
      }
    }

    _emit(
      AdventureCameraStatus(
        phase: AdventureCameraPhase.error,
        deviceName: _status.deviceName,
        message: 'Shutter failed: $lastError',
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
  }

  void _emit(AdventureCameraStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
