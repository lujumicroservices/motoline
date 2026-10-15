---
name: metrica
description: >-
  Índice y orquestador del producto Métrica (firmware logger + app de pareo).
  Usa cuando el usuario diga /metrica, M5 logger, firmware 0.6.x, o pida
  trabajar cualquier módulo del logger. Lista skills expertos y enruta.
---

# Métrica — índice

Producto: logger M5Stack (**Basic + M135**) + app RiderLab (pareo BLE/USB, Wi‑Fi paddock).

Árbol firmware: `hardware/firmware/` (versión en `include/HardwareConfig.h`).
Estado / BOM: skills `hardware` y `riderlab-estado` (no los reemplaza).

## Skills expertos

### Firmware (`hardware/firmware/`)

| Skill | Módulo | Archivos clave |
|---|---|---|
| `metrica-core` | Boot, loop, roles, serial | `src/main.cpp`, `HardwareConfig.h`, `RoleConfig.h`, `platformio.ini` |
| `metrica-gnss` | GNSS / UBX / PPS | `GnssService.h`, `UbxParser.h`, `GpsClock.h`, `PpsClock.*` |
| `metrica-imu-baro` | IMU + barómetro | `ImuService.h`, `BaroService.h`, `src/Bmi270Config.cpp` |
| `metrica-ui` | Pantalla, menús, trail | `UiChrome.h`, `CircuitView.h`, `BrandIcon.h` |
| `metrica-circuit` | Pista embebida, laps, delta | `CircuitEmbedded*.h`, `CircuitFile.h`, `CircuitIndex.h`, `LapTimer.h`, `LiveDelta.h` |
| `metrica-session` | Grabación SD / índices | `TelemetryLogger.h`, `RideIndex.h`, `EventLog.h`, `DiagLog.h` |
| `metrica-wifi-upload` | Wi‑Fi + subida Azure | `WifiUploader.h`, `UploadTask.h` |
| `metrica-ble` | GATT pareo en el M5 | `BlePair.h` (+ contrato app) |
| `metrica-anchor` | Rol ANCHOR + post-proceso | `AnchorEngine.h`, `ANCHOR.md`, `tools/anchor_correct.py` |

### App móvil (pareo / logger)

| Skill | Módulo | Archivos clave |
|---|---|---|
| `metrica-app-ble` | Pareo BLE + Wi‑Fi paddock | `metrica_ble_*.dart`, `metrica_paddock_wifi.dart`, `metrica_ble_pair_section.dart` |
| `metrica-app-pair` | Pantalla logger / PAIR USB | `logger_hardware_screen.dart`, `logger_pairing_service.dart` |

## Integración app OFF ↔ Métrica (BLE)

Flujo de producto:

1. Modo **OFF** → home → **Métrica** (o Settings → M5 Logger).
2. En el M5: menú **EMPAREJAR** (firmware `metrica-ble`, no grabando).
3. App: scan → PIN → elegir Wi‑Fi paddock (`metrica-app-ble`) → PAIR.
4. Tras pareo, sesiones suben por Wi‑Fi (`metrica-wifi-upload`); circuitos/sesiones OFF consumen datos (`offroad-*`).

## Enrutar

1. Leer este índice y `HardwareConfig.h` (versión FW).
2. Abrir el skill del módulo tocado.
3. No mezclar BOM/compras (`hardware`) con bugs de firmware salvo que el usuario lo pida.
4. BLE: firmware `metrica-ble` y app `metrica-app-ble` deben cuadrar el mismo contrato UUID/STATUS.
5. UI OFF / tema: skills `offroad-home`, `offroad-theme`.

## Language

Match the user (usually Spanish).
