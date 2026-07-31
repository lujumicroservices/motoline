# Adventure camera lab (experimental)

Isolated feature under `apps/mobile/lib/features/adventure_camera/`.

**Does not** change core GPS / lean / SQLite ride recording. Ride hooks are a soft Riverpod listener (`AdventureCameraLifecycleBinder`).

## Enable

Settings → **Lab** → enable Adventure camera.

- **GoPro BLE** — Open GoPro shutter start/stop (Hero 9+ style UUIDs)
- **Simulated** — fake camera for UI/dev without hardware

## Ride sync

When “Record with ride” is on:

| Ride event | Camera |
|------------|--------|
| Recording starts | `startRecording()` (connects first if needed) |
| Recording ends | `stopRecording()` |
| Auto-pause (optional) | stop / start shutter |

Camera failures never abort the ride.

## Files

| Path | Role |
|------|------|
| `adventure_camera_hub.dart` | Orchestration + prefs |
| `gopro/gopro_ble_camera.dart` | Open GoPro BLE |
| `simulated_camera_controller.dart` | Dev fake |
| `widgets/*` | Settings + CAM chip + lifecycle binder |

## Build notes

Android: `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` in manifest.  
Package: `flutter_blue_plus`.
