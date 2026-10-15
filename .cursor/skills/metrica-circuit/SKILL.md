---
name: metrica-circuit
description: >-
  Experto circuito embebido Métrica: RLC1 suave, sectores, gates, LapTimer,
  LiveDelta. Usa con /metrica-circuit, CircuitEmbedded, CircuitIndex, lap
  timer, o suavizado de pista.
---

# Métrica — Circuito embebido

## Alcance

- `CircuitEmbedded.h`, `CircuitEmbedded_suave.h`
- `CircuitFile.h`, `CircuitIndex.h`, `CircuitElevation.h`
- `LapTimer.h`, `LiveDelta.h`
- Relación con app OFF: export → `offroad-circuits` / `offroad-assets`

## Reglas

1. Geometría de producto = **suave**; crudo solo auditoría.
2. Sectores F1 / gates; centerline y anchos para corredor.
3. Cambios de embebido afectan M5 y deben re-exportarse a la app si la app los muestra.
4. No editar a mano miles de puntos: regenerar con tools de suavizado / make_*.

## Al retomar

Plan off-road §1 + headers embedded. Si toca app JSON: `offroad-assets`.

## Language

Match the user (usually Spanish).
