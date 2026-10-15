---
name: offroad
description: >-
  Índice y orquestador de la variante OFF (off-road) de RiderLab. Usa cuando el
  usuario diga /offroad, modo OFF, off-road, Métrica app OFF, o pida trabajar
  cualquier módulo de la experiencia off-road. Lista los skills expertos por
  módulo y enruta al correcto.
---

# OFF — RiderLab off-road

Una app, dos modos. **OFF** = circuitos / entrenamiento; **ON** = calle (no tocar desde aquí salvo el toggle).

Plan vivo: `docs/plan-riderlab-offroad.md` (sección 0 manda).

## Skills expertos (módulos)

| Skill | Módulo | Código principal |
|---|---|---|
| `offroad-mode` | Selector ON/OFF, persistencia, sonido | `lib/core/app_mode.dart`, `mode_switch_sound.dart`, `widgets/mode_toggle.dart` |
| `offroad-theme` | Identidad visual Métrica | `lib/theme/offroad_theme.dart` |
| `offroad-home` | Home OFF (rendimiento + accesos) | `lib/features/offroad/offroad_home_screen.dart` |
| `offroad-circuits` | Circuitos mapeados, detalle, silueta | `circuit_model.dart`, `circuits_list_*`, `circuit_detail_*`, `assets/circuits/` |
| `offroad-sessions` | Sesiones de entrenamiento | `session_model.dart`, `sessions_*`, `assets/offroad/sessions/` |
| `offroad-pass-analysis` | Análisis de pasada vs mejor | `pass_analysis.dart`, `pass_detail_screen.dart` |
| `offroad-assets` | Export JSON, seed, tools | `tool/export_circuit_asset.py`, `tool/build_training_session.py` |

Relacionado pero **fuera** del producto OFF (lab experimental):

| Skill | Qué es |
|---|---|
| `circuit-8h` | Survey GPS A/B del circuito 8 Horas (experimental) |
| `hardware` | Logger Métrica / firmware / BOM |

## Enrutar

1. Leer este índice.
2. Abrir el skill del módulo que el usuario toca.
3. No mezclar ON (calle) con OFF salvo `app_mode` / toggle.
4. No inventar geometría: circuitos suaves vienen de Métrica / assets exportados.

## Language

Match the user (usually Spanish).
