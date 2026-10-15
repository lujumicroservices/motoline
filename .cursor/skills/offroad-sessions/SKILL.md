---
name: offroad-sessions
description: >-
  Experto de sesiones de entrenamiento OFF: modelo, lista, detalle, coaching
  (bien/mal) y filtro por cuenta. Usa con /offroad-sessions, TrainingSession,
  sesiones OFF, o assets/offroad/sessions.
---

# OFF — Sesiones

## Alcance

- `apps/mobile/lib/features/offroad/session_model.dart`
- `sessions_list_screen.dart`, `session_detail_screen.dart`
- Assets: `apps/mobile/assets/offroad/sessions/*.json`
- Tabs: coaching / pasadas / resumen

## Modelo

`TrainingSession`: dueño (alias/email), circuito, fecha, pasadas, summary (best, sectores, flying laps), insights good/bad. Visible solo si `ownerMatches` la cuenta firmada.

## Reglas

1. Seed actual: sesión 8 Horas para `lujumicroservices` (pasadas logger).
2. Coaching = insights del JSON; no inventar tips genéricos sin datos.
3. Detalle enlaza a `pass_detail` (skill `offroad-pass-analysis`).
4. Strings `offroad*` en arb; regenerar l10n si añades claves.

## Al retomar

`session_model.dart` + asset de la sesión. Tool de seed: `offroad-assets`.

## Language

Match the user (usually Spanish).
