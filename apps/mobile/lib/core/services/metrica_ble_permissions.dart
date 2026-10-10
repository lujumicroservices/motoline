import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'metrica_ble_protocol.dart';

/// Which runtime prompts the phone needs before a Métrica scan.
enum MetricaBlePermissionPlan {
  /// Android 12+ (API 31): BLUETOOTH_SCAN and BLUETOOTH_CONNECT.
  /// Location is not requested. The manifest marks SCAN `neverForLocation`.
  android12ScanConnect,

  /// Android 11 and older: location is what allows a BLE scan.
  legacyLocation,

  /// iOS prompts from the Bluetooth usage string.
  appleBluetooth,
}

class MetricaBleAccess {
  const MetricaBleAccess(this.plan);

  final MetricaBlePermissionPlan plan;

  /// Pre-Android 12 scans need fine location. Android 12+ must stay false
  /// because BLUETOOTH_SCAN is declared `neverForLocation`.
  bool get usesFineLocation => plan == MetricaBlePermissionPlan.legacyLocation;
}

const _platform = MethodChannel('com.rawthrottle.riderlab/platform');

/// Android `Build.VERSION.SDK_INT` from [MainActivity], or null off Android.
Future<int?> readAndroidSdkInt() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  try {
    return await _platform.invokeMethod<int>('sdkInt');
  } catch (_) {
    return null;
  }
}

MetricaBleAccess chooseBlePermissions({
  required bool isAndroid,
  required int? androidSdkInt,
}) {
  if (!isAndroid) {
    return const MetricaBleAccess(MetricaBlePermissionPlan.appleBluetooth);
  }
  if (androidSdkInt != null && androidSdkInt >= 31) {
    return const MetricaBleAccess(
      MetricaBlePermissionPlan.android12ScanConnect,
    );
  }
  return const MetricaBleAccess(MetricaBlePermissionPlan.legacyLocation);
}

class MetricaBlePermissions {
  const MetricaBlePermissions({this.sdkInt});

  /// Test hook. Production reads [readAndroidSdkInt].
  final Future<int?> Function()? sdkInt;

  Future<MetricaBleAccess> ensure() async {
    if (kIsWeb) {
      throw const MetricaBleException(MetricaBleFailure.unsupported);
    }
    final android = Platform.isAndroid;
    final sdk = android ? await (sdkInt ?? readAndroidSdkInt)() : null;
    final access = chooseBlePermissions(isAndroid: android, androidSdkInt: sdk);
    switch (access.plan) {
      case MetricaBlePermissionPlan.android12ScanConnect:
        final statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        if (!_granted(statuses[Permission.bluetoothScan]) ||
            !_granted(statuses[Permission.bluetoothConnect])) {
          throw const MetricaBleException(MetricaBleFailure.permissionDenied);
        }
      case MetricaBlePermissionPlan.legacyLocation:
        final location = await Permission.locationWhenInUse.request();
        if (!_granted(location)) {
          throw const MetricaBleException(MetricaBleFailure.locationDenied);
        }
      case MetricaBlePermissionPlan.appleBluetooth:
        final bluetooth = await Permission.bluetooth.request();
        if (!_granted(bluetooth)) {
          throw const MetricaBleException(MetricaBleFailure.permissionDenied);
        }
    }
    return access;
  }
}

bool _granted(PermissionStatus? status) {
  if (status == null) return false;
  return status.isGranted || status.isLimited;
}
