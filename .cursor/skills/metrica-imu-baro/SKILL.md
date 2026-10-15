---
name: metrica-imu-baro
description: >-
  Experto IMU BMI270 y barómetro BMP280 en el M135. Usa con /metrica-imu-baro,
  ImuService, BaroService, lean, COLOC, o Bmi270Config.
---

# Métrica — IMU / Baro

## Alcance

- `include/ImuService.h`, `BaroService.h`
- `src/Bmi270Config.cpp` (config ~8 KB; lean crudo)
- Uso en sesión: `imu.ndjson`, `baro.ndjson`; ancla: barometría diferencial / `COLOC`

## Reglas

1. BMI270 necesita el blob de config correcto; sin él `|a|≈0`.
2. BMP280 está en el **módulo M135**, no en el Basic.
3. Baro = relativo / tendencia; viento distorsiona. No vender altitud de berma.
4. `COLOC` (C 1 s) calibra juntos ancla+moto al inicio/fin (ver `metrica-anchor`).

## Al retomar

Archivo del sensor + cómo se loguea en `TelemetryLogger`. Skill ancla si es diferencial.

## Language

Match the user (usually Spanish).
