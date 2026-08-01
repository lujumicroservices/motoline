/// Open GoPro BLE UUIDs (HERO9+ / Open GoPro).
/// See https://gopro.github.io/OpenGoPro/
class GoProBleUuids {
  GoProBleUuids._();

  static const service = '0000fea6-0000-1000-8000-00805f9b34fb';

  /// Command request (write shutter / mode commands).
  static const commandRequest = 'b5f90072-aa8d-11e3-9046-0002a5d5c51b';

  /// Command response (notifications).
  static const commandResponse = 'b5f90073-aa8d-11e3-9046-0002a5d5c51b';

  /// Settings request (keep-alive LED write).
  static const settingsRequest = 'b5f90074-aa8d-11e3-9046-0002a5d5c51b';

  /// Settings response (notifications).
  static const settingsResponse = 'b5f90075-aa8d-11e3-9046-0002a5d5c51b';

  /// Set Shutter ON — Open GoPro TLV.
  static final shutterOn = <int>[0x03, 0x01, 0x01, 0x01];

  /// Set Shutter OFF.
  static final shutterOff = <int>[0x03, 0x01, 0x01, 0x00];

  /// LED setting used as BLE keep-alive (`SettingId.LED` = 0x5B, value BLE_KEEP_ALIVE).
  static final keepAlive = <int>[0x03, 0x5B, 0x01, 0x3D];
}
