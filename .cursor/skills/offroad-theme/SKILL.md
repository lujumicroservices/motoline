---
name: offroad-theme
description: >-
  Experto del tema visual OFF (identidad Métrica): colores de pista, sectores,
  tipografía y contraste. Usa con /offroad-theme, OffroadTheme, tema Métrica
  app, o al tocar offroad_theme.dart / branding OFF.
---

# OFF — Tema Métrica

## Alcance

- `apps/mobile/lib/theme/offroad_theme.dart`
- Tokens alineados al firmware Métrica (pista naranja, sectores S1–S4)
- Icono wheelie / branding OFF (no mezclar PNG de calle)

## Tokens (referencia)

| Rol | Notas |
|---|---|
| Fondo | Oscuro tipo Métrica |
| Pista / corredor | Naranja brillante `#FF8C00` |
| Sectores | S1 rojo, S2 cyan, S3 verde, S4 magenta |
| Texto | Alto contraste; legible al sol |

## Reglas

1. OFF no tiene selector de tema claro/oscuro propio: es el look Métrica.
2. No reutilizar iconos de navegación de ON; trazo propio OFF.
3. Cambios de color deben cuadrar con lo que pinta el M5 (misma familia de producto).

## Al retomar

Leer plan §0 “Tema OFF: el de Métrica”. Editar solo `offroad_theme.dart` salvo assets de branding.

## Language

Match the user (usually Spanish).
