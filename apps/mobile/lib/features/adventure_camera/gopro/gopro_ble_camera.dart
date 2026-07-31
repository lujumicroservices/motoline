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
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

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
      );

      found = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _scanSub = null;

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

    await _connSub?.cancel();
    _device = device;
    await device.connect(autoConnect: false);
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _commandRequest = null;
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
    for (final s in services) {
      for (final c in s.characteristics) {
        final id = c.uuid.str128.toLowerCase();
        if (id == GoProBleUuids.commandRequest.toLowerCase()) {
          cmd = c;
        } else if (id == GoProBleUuids.commandResponse.toLowerCase()) {
          rsp = c;
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
    if (rsp != null && rsp.properties.notify) {
      try {
        await rsp.setNotifyValue(true);
      } catch (e) {
        debugPrint('GoPro notify: $e');
      }
    }

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

  @override
  Future<void> disconnect() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      await FlutterBluePlus.stopScan();
      await _connSub?.cancel();
      _connSub = null;
      _commandRequest = null;
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
    await _writeShutter(on: true);
  }

  @override
  Future<void> stopRecording() async {
    await _writeShutter(on: false);
  }

  Future<void> _writeShutter({required bool on}) async {
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
    try {
      final bytes = on ? GoProBleUuids.shutterOn : GoProBleUuids.shutterOff;
      await cmd.write(bytes, withoutResponse: false);
      _emit(
        AdventureCameraStatus(
          phase: on
              ? AdventureCameraPhase.recording
              : AdventureCameraPhase.ready,
          deviceName: _status.deviceName,
          message: on ? 'Camera recording' : 'Camera idle',
        ),
      );
    } catch (e) {
      debugPrint('GoPro shutter: $e');
      _emit(
        AdventureCameraStatus(
          phase: AdventureCameraPhase.error,
          deviceName: _status.deviceName,
          message: 'Shutter failed: $e',
        ),
      );
    }
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
