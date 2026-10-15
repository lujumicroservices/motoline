---
name: metrica-app-pair
description: >-
  Experto pantalla logger / PAIR por USB y claim de dispositivo en la app.
  Usa con /metrica-app-pair, LoggerHardwareScreen, logger_pairing_service,
  o pair-logger-device.
---

# Métrica — App PAIR (USB / cloud)

## Alcance

- `apps/mobile/lib/features/settings/logger_hardware_screen.dart`
- `apps/mobile/lib/core/services/logger_pairing_service.dart`
- Edge: `supabase/functions/pair-logger-device/`, ingest logger
- Entrada Settings → M5 Logger (incluye sección BLE)

## Reglas

1. Mint `claim_code` / claim → `device_id` + `secret` + `ingest_url` (app reenvía URL tal cual).
2. USB PAIR en serial del M5 sigue válido junto al BLE.
3. Requiere sesión Supabase firmada.
4. No mostrar secret en UI ni snacks.

## Al retomar

`logger_pairing_service.dart` + función Supabase si falla el mint. BLE UI: `metrica-app-ble`.

## Language

Match the user (usually Spanish).
