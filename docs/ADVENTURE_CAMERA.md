# Adventure camera lab (experimental)

Isolated feature under `apps/mobile/lib/features/adventure_camera/`.

**Does not** change core GPS / lean / SQLite ride recording. Ride hooks are a soft Riverpod listener (`AdventureCameraLifecycleBinder`).

## Enable

Settings → **Lab** → enable Adventure camera.

- **GoPro BLE** — Open GoPro shutter start/stop (Hero 9+ style UUIDs)
- **Simulated** — fake camera for UI/dev without hardware

## Triggers

| Mode | Behavior |
|------|----------|
| Record with ride | Start/stop shutter with GPS ride start/end |
| Follow auto-pause | Optional stop/start with GPS auto-pause |
| Map start/stop zones | Multiple geofences; enter start → record, enter stop → idle. Turn off “Record with ride” to record *only* in zones |
| Aggressive riding | Auto-start on sustained lean (~22°+) or hard acceleration |

Camera failures never abort the ride.

## Cold-start fix

When the GoPro was off/asleep, BLE connect wakes it but an immediate shutter was ignored. Connect now:

1. Discovers GATT + enables notifications  
2. Waits ~2.5s for boot  
3. Sends LED keep-alive (`0x03 0x5B 0x01 0x3D`)  
4. Retries shutter several times with backoff  
5. Keeps a periodic keep-alive while connected  

## Files

| Path | Role |
|------|------|
| `adventure_camera_hub.dart` | Orchestration + prefs + zone/aggressive hooks |
| `gopro/gopro_ble_camera.dart` | Open GoPro BLE + cold wake |
| `camera_zone_detector.dart` | Edge-triggered geofence enter |
| `aggressive_riding_detector.dart` | Lean / accel trigger |
| `widgets/camera_zones_map_screen.dart` | Multi start/stop map editor |
| `simulated_camera_controller.dart` | Dev fake |
| `widgets/*` | Settings + CAM chip + lifecycle binder |

## Build notes

Android: `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` in manifest.  
Package: `flutter_blue_plus`.
