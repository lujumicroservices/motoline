---
name: metrica-core
description: >-
  Experto del núcleo firmware Métrica: main loop, roles RIDER/ANCHOR, serial
  HELP/STATUS, build PlatformIO. Usa con /metrica-core, main.cpp logger, ROLE,
  o platformio.ini del firmware.
---

# Métrica — Core

## Alcance

- `hardware/firmware/src/main.cpp`
- `include/HardwareConfig.h` (`FIRMWARE_VERSION`, pines, nombre)
- `include/RoleConfig.h` — NVS RIDER / ANCHOR
- `platformio.ini`, `README.md`, `BENCH_CHECKLIST.md`

## Reglas

1. Un solo firmware, dos roles (`ROLE RIDER|ANCHOR`, A+C al boot).
2. Stack físico: Basic → M135 → Battery 13.2 → Bottom Base (`switch=0`).
3. Serial 115200; comandos de provisión documentados en README / ANCHOR.
4. Antes de flash outdoor: checklist de banco.
5. Cambios de versión: actualizar `FIRMWARE_VERSION` y STATUS si aplica.

## Al retomar

Leer versión en `HardwareConfig.h` + tramo de `main.cpp` que vas a tocar. Skill índice: `metrica`.

## Language

Match the user (usually Spanish).
