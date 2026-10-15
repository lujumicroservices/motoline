---
name: metrica-wifi-upload
description: >-
  Experto Wi‑Fi y subida de sesiones Métrica (Azure ingest, cola, HTTPS). Usa
  con /metrica-wifi-upload, WifiUploader, UploadTask, PAIR ingest_url, o WIFI
  serial.
---

# Métrica — Wi‑Fi / Upload

## Alcance

- `WifiUploader.h` — SSIDs, join, scan
- `UploadTask.h` — cola, POST, fallos, tope de tamaño
- Provisión: serial `WIFI ssid|pass`, `PAIR id|secret|ingest_url`
- BLE puede escribir WIFI antes de PAIR (app: `metrica-app-ble`)

## Reglas

1. ESP32 Basic = **solo 2.4 GHz**.
2. Tras `paired`, el logger cierra modo pareo en ~3 s: Wi‑Fi **antes** del PAIR por BLE.
3. Ingest usa header tipo `X-Logger-Key` / secret; no loguear secret ni password.
4. Fallos Azure: revisar `LOG` / EventLog; sesiones grandes pueden truncarse (tope POST).

## Al retomar

`WifiUploader.h` + `UploadTask.h`. Credenciales paddock en app: `metrica-app-ble`.

## Language

Match the user (usually Spanish).
