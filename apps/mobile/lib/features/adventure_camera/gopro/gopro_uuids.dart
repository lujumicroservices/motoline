/// Open GoPro BLE UUIDs (HERO9+ / Open GoPro).
/// See https://gopro.github.io/OpenGoPro/
class GoProBleUuids {
  GoProBleUuids._();

  static const service = '0000fea6-0000-1000-8000-00805f9b34fb';

  /// Command request (write shutter / mode commands).
  static const commandRequest = 'b5f90072-aa8d-11e3-9046-0002a5d5c51b';

  /// Command response (notifications).
  static const commandResponse = 'b5f90073-aa8d-11e3-9046-0002a5d5c51b';

  /// Set Shutter ON — Open GoPro TLV.
  static final shutterOn = <int>[0x03, 0x01, 0x01, 0x01];

  /// Set Shutter OFF.
  static final shutterOff = <int>[0x03, 0x01, 0x01, 0x00];
}
