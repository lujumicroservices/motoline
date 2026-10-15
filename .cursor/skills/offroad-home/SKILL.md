---
name: offroad-home
description: >-
  Experto del home OFF: rendimiento, accesos a Circuitos y Sesiones, ModeToggle.
  Usa con /offroad-home, home OFF, Mis circuitos home, o al tocar
  offroad_home_screen.dart.
---

# OFF — Home

## Alcance

- `apps/mobile/lib/features/offroad/offroad_home_screen.dart`
- Strip de rendimiento (`offroadPerformanceProvider` en `session_model.dart`)
- Acciones: Circuitos, Sesiones, **Métrica** (pareo BLE → `LoggerHardwareScreen`)
- `ModeToggle` + perfil en app bar

## Reglas

1. Home OFF = hub de entrenamiento, no clon del home ON.
2. Stats vienen de sesiones bundled / filtradas por cuenta (`lujumicroservices`, alias).
3. Composición: tagline, rendimiento, Circuitos + Sesiones + Métrica. Sin dashboard de calle.
4. Pareo BLE es skill `metrica-app-ble`; no duplicar lógica GATT en el home.
5. Strings en l10n (`offroad*`): no hardcodear textos de UI.

## Al retomar

Abrir `offroad_home_screen.dart` y el provider que alimenta el strip. Plan §0 “Home OFF”.

## Language

Match the user (usually Spanish).
