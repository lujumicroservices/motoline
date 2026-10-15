---
name: metrica-anchor
description: >-
  Experto rol ANCHOR Métrica: estación de referencia, REF, COLOC, anchor_correct.
  Usa con /metrica-anchor, AnchorEngine, ANCHOR.md, o corrección diferencial.
---

# Métrica — Ancla

## Alcance

- `include/AnchorEngine.h`, `RoleConfig.h`
- `hardware/firmware/ANCHOR.md`
- `tools/anchor_correct.py`, `tools/test_anchor_correct.py`
- Pantalla/comportamiento ancla en `main.cpp` / UiChrome

## Reglas

1. Mismo receptor/config que RIDER; diferencia = posición de referencia + baro.
2. Procedimiento físico: plano de tierra, DIP, COM flash — ver ANCHOR.md.
3. Post-proceso: `anchor_correct.py` (moto − error ancla); correr tests al tocar.
4. No prometer RTK fixed en M9N; diferencial de posición es la historia actual.
5. Estado vivo: `riderlab-estado` + `hardware/STATUS.md`.

## Al retomar

ANCHOR.md + STATUS. Compilar/flashear solo con checklist de banco.

## Language

Match the user (usually Spanish).
