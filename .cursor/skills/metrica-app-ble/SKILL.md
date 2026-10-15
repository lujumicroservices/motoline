---
name: metrica-app-ble
description: >-
  Experto pareo BLE Métrica en la app Flutter: scan, PIN, Wi‑Fi paddock picker,
  permisos. Usa con /metrica-app-ble, metrica_ble_client, paddock wifi, o
  Pair over Bluetooth.
---

# Métrica — App BLE

## Alcance

- `metrica_ble_protocol.dart`, `metrica_ble_client.dart`, `metrica_ble_pairing.dart`
- `metrica_ble_permissions.dart`, `metrica_ble_pair_section.dart`
- `metrica_paddock_wifi.dart` — redes Infinitum / Hotspot Galaxy, etc.
- Android: `MainActivity` `sdkInt` / `currentWifiSsid`, permisos SCAN/CONNECT

## Reglas

1. `startScan` **no** espera el timeout solo: hay que await `isScanning` / delay (bug ya corregido).
2. Match ADV: nombre **o** UUID; mergear callbacks por `remoteId`.
3. Android no entrega password del sistema: perfiles paddock + remember.
4. Flujo: scan → connect → INFO → PIN → (WIFI) → mint/claim → PAIR.
5. Nunca loguear `secret` ni password Wi‑Fi.
6. Tests: `test/metrica_ble_*_test.dart`.

## Al retomar

Protocolo FW (`metrica-ble`) + client/UI. Build sideload para Galaxy al cerrar fix.

## Language

Match the user (usually Spanish).
