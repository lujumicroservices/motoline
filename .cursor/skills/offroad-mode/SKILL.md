---
name: offroad-mode
description: >-
  Experto del selector ON/OFF de RiderLab: persistencia del modo, sonidos de
  cambio, haptics y gate de arranque. Usa con /offroad-mode, modo ON OFF,
  ModeToggle, mode_switch_sound, o al tocar app_mode.dart.
---

# OFF — Modo ON/OFF

## Alcance

- `apps/mobile/lib/core/app_mode.dart` — `AppMode`, `appModeProvider`, `modeSoundEnabledProvider`
- `apps/mobile/lib/core/services/mode_switch_sound.dart`
- `apps/mobile/lib/widgets/mode_toggle.dart`
- Entrada en `auth_gate.dart` / `main.dart` según `AppMode`
- Ajuste “sonido al cambiar modo” en Settings
- Assets: `assets/sounds/mode_off_*.wav|ogg`, `mode_on_*.wav|ogg`

## Reglas

1. ON = calle intacta. OFF = experiencia off-road. Misma app / mismo `applicationId`.
2. El modo se guarda en SharedPreferences (`riderlab_app_mode`).
3. Sonido **solo al cambiar** de modo, nunca al abrir la app ni con rodada grabando.
4. ON→OFF = 2T tierra; OFF→ON = pista 4T. Respetar silencio del teléfono y el toggle de Settings.
5. Haptic al cambiar. No añadir selector de tema dentro de OFF.

## Al retomar

Leer `docs/plan-riderlab-offroad.md` §0 (definición ON/OFF + sonidos). Luego el archivo que vas a editar.

## Language

Match the user (usually Spanish).
