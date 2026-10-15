---
name: offroad-pass-analysis
description: >-
  Experto del análisis de pasada OFF vs mejor del día: sectores, pace factors,
  frenadas. Usa con /offroad-pass-analysis, PassAnalysis, pass_detail, o
  comparación de pasadas.
---

# OFF — Análisis de pasada

## Alcance

- `apps/mobile/lib/features/offroad/pass_analysis.dart`
- `pass_detail_screen.dart`

## Conceptos

- `SectorDelta`: tiempo vs mejor sector volador del día (parciales no comparan).
- `PaceFactor`: good / bad / info (por qué el ritmo).
- Referencia = mejor pasada de la misma sesión, no un récord global inventado.

## Reglas

1. Positivo en delta = más lento que el best.
2. No comparar sectores `partial` / stopped como si fueran flying.
3. UI: sectores vs best, por qué el pace, zonas de frenada si hay datos.
4. Depende del `TrainingSession` / `TrainingPass` de `offroad-sessions`.

## Al retomar

Leer `pass_analysis.dart` antes de tocar la UI. Mantener la misma semántica de deltas.

## Language

Match the user (usually Spanish).
