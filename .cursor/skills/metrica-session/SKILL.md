---
name: metrica-session
description: >-
  Experto grabación de sesión Métrica en SD: TelemetryLogger, RideIndex,
  EventLog, layout /riderlab/sessions. Usa con /metrica-session, REC, NDJSON,
  KEEPSD, o RideIndex.
---

# Métrica — Sesión / SD

## Alcance

- `TelemetryLogger.h` — start/stop, manifiestos, streams NDJSON
- `RideIndex.h` — índice de rides; SIMPOS también pending (0.6.9b)
- `EventLog.h`, `DiagLog.h`
- Layout: `/riderlab/sessions/<id>/{manifest,gnss,pvt,sat,dop,imu,baro,...}`

## Reglas

1. Partición 16 MB (`default_16MB.csv`); NVS conserva config.
2. `KEEPSD ON` evita borrar tras upload (ancla: siempre).
3. Heartbeat / eventos no deben ahogar el log GNSS.
4. SIMPOS: sesiones de banco entran a cola de upload como reales (0.6.9b).

## Al retomar

`TelemetryLogger.h` + comandos REC en `main.cpp`. Upload: `metrica-wifi-upload`.

## Language

Match the user (usually Spanish).
