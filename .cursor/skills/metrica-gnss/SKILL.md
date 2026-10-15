---
name: metrica-gnss
description: >-
  Experto GNSS Métrica: UBX PVT/SAT/DOP, 10 Hz, PPS, pines DIP M135. Usa con
  /metrica-gnss, GnssService, UbxParser, PINSCAN, NEO-M9N, o PPS.
---

# Métrica — GNSS

## Alcance

- `include/GnssService.h`, `UbxParser.h`, `GpsClock.h`
- `include/PpsClock.h`, `src/PpsClock.cpp`
- DIP / pines: `README.md`, `ANCHOR.md` (RXD/TXD/PPS)

## Reglas

1. Receptor se **configura** en firmware (no dejar NMEA 1 Hz de fábrica).
2. Target: 10 Hz multi-GNSS, UART 115200, UBX NAV-PVT/SAT/DOP.
3. M9N es L1; no prometer RTK/cm en este BOM.
4. `PINSCAN` / hold B al boot para validar pines por unidad.
5. Silkscreen DIP es desde el lado del receptor; verificar notas medidas.

## Al retomar

`GnssService.h` + notas DIP del README. No inventar precisión submétrica.

## Language

Match the user (usually Spanish).
