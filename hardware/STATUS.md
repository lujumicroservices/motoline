# STATUS — hardware

> Archivo vivo. Última actualización: 2026-10-03 (cloud 15 rides)

## Fase

**0.4.9-log** — log de eventos/errores en SD + Serial (`/riderlab/events.ndjson`). USB: `LOG` y `LOGCLR`.

## Stack

Basic → M135 → Battery 13.2 → Bottom Base (`switch=0`).
ESP32 Basic = **solo 2.4 GHz**.

## Hecho en código

- Boot: reset reason, heap, GNSS/IMU/BARO/SD, cola Azure.
- REC start/stop, Wi‑Fi join, HTTPS warm/POST, fallos de índice/SD.
- Heartbeat 60 s. Duplicados iguales no se reescriben en SD cada 20 s.
- GNSS 1 Hz sigue solo por Serial (no llena el log).

## Nube

15 sesiones en `logger-sessions/unpaired` (3 oct). Mapa: `captures/cloud_rides.html`. Dos recortadas al tope 24 kB del POST.

## Siguiente paso

1. Flash 0.4.9. USB 115200: al arrancar deben salir líneas `{"t":…,"lvl":"I"…}`.
2. Tras un fallo de Azure, `LOG` debe mostrar el `https` E.

## Preguntas abiertas

- Antena SparkFun vs incluida.
- BLE live (fuera de este plan).

## Fuera de alcance

Shop / landing / Play.
