---
name: metrica-ble
description: >-
  Experto GATT de pareo en firmware Métrica (BlePair, UUIDs 6f8a*, PIN, STATUS).
  Usa con /metrica-ble, BlePair.h, modo emparejamiento M5, o contrato 0.6.8-ble.
---

# Métrica — BLE (firmware)

## Alcance

- `hardware/firmware/include/BlePair.h`
- Nombre ADV: `Metrica-XXXX` (últimos 2 bytes MAC Wi‑Fi STA, hex mayúsculas)
- Servicio `6f8a0001-5c3e-4b8e-9a51-4d4554524943` + INFO/AUTH/PAIR/WIFI/STATUS
- Fragmentos write `0x1E`, MTU 247; STATUS `msg`/`err`/`left`

## Reglas

1. Subscribe STATUS antes de escribir; una respuesta por write.
2. WIFI opcional **antes** de PAIR; secret nunca en logs/pantalla.
3. PIN 6 dígitos; 5 fallos → sale de pairing mode (`left` 0).
4. Contrato debe coincidir con app (`metrica-app-ble` / `metrica_ble_protocol.dart`).
5. ADV vs scan response: UUID y nombre pueden ir en paquetes distintos (la app ya mergea).

## Al retomar

`BlePair.h` + comentarios de protocolo en `apps/mobile/.../metrica_ble_protocol.dart`.

## Language

Match the user (usually Spanish).
