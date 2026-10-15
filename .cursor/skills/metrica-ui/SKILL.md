---
name: metrica-ui
description: >-
  Experto UI Métrica en M5 (320×240): UiChrome, CircuitView, Trail 0.6.9,
  BrandIcon. Usa con /metrica-ui, pantalla logger, trail view, VIEW TRAIL,
  o UiPage.
---

# Métrica — UI

## Alcance

- `include/UiChrome.h` — páginas, status bar, menú, About
- `include/CircuitView.h` — follow / bare follow (trail sin circuito)
- `include/BrandIcon.h` — wheelie
- Handlers en `main.cpp` (botones A/B/C por página, `trailOpen` / `VIEW TRAIL`)

## Reglas (0.6.9+)

1. Sin circuito en sesión → página **Trail** (bare follow + speed header).
2. Status bar home compartida con Trail (0.6.9b).
3. Zoom bare default 150 m (0.6.9c); un solo view a la vez (trail vs circuit).
4. Colores de pista/sectores alinean con tema OFF de la app (`offroad-theme`).

## Al retomar

`UiChrome.h` + tramo Trail en `main.cpp` / `CircuitView.h`. Versión FW en HardwareConfig.

## Language

Match the user (usually Spanish).
