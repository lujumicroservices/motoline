---
name: offroad-assets
description: >-
  Experto de assets y tools OFF: export de circuitos JSON, seed de sesiones de
  entrenamiento, pubspec assets. Usa con /offroad-assets, export_circuit_asset,
  build_training_session, o al regenerar 8horas.json / sessions JSON.
---

# OFF — Assets y tools

## Alcance

- `apps/mobile/assets/circuits/` — geometría suave para la app
- `apps/mobile/assets/offroad/sessions/` — sesiones de entrenamiento
- `apps/mobile/assets/sounds/` — cues ON/OFF (licencia clara)
- Tools: `apps/mobile/tool/export_circuit_asset.py`, `build_training_session.py`, `build_mode_sounds.py`
- Declarar paths en `apps/mobile/pubspec.yaml` → `flutter: assets:`

## Reglas

1. Geometría de producto = export del suave Métrica; no pegar bordes crudos como default.
2. Sesiones: JSON estable con owner, passes, summary, insights; filtrado en app por cuenta.
3. Tras regenerar assets: verificar que el APK sideload los incluye (`pubspec`).
4. No commitear secretos ni dumps enormes de GPS crudo sin necesidad.

## Al retomar

Ver qué asset falta o está viejo; correr el tool correspondiente; no editar JSON a mano salvo fix puntual.

## Language

Match the user (usually Spanish).
