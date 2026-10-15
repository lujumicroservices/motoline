---
name: offroad-circuits
description: >-
  Experto de circuitos OFF: modelo, lista, detalle, silueta y assets JSON del
  mapeo suave. Usa con /offroad-circuits, circuito 8 Horas app, Circuit,
  circuits_list, circuit_detail, o assets/circuits.
---

# OFF — Circuitos

## Alcance

- `apps/mobile/lib/features/offroad/circuit_model.dart`
- `circuits_list_screen.dart`, `circuit_detail_screen.dart`
- `widgets/circuit_silhouette.dart`
- Assets: `apps/mobile/assets/circuits/*.json` (hoy `8horas.json`)
- Export: ver skill `offroad-assets`

## Modelo

`Circuit`: id, place, mappedOn, bordes, centerline, gates, sectores, smoothing QA, elevación. Geometría de referencia = suave Métrica (no el trazo crudo para medir).

## Reglas

1. No reinventar el mapa: export desde firmware / tool; la app solo consume JSON.
2. Trazo crudo es capa opcional de auditoría, no default.
3. Sectores estilo F1 (gates); anchos y elevación vienen del asset.
4. Relacionado con survey GPS: skill `circuit-8h` (lab), no confundir con este módulo de producto.

## Al retomar

Leer plan §1 (geometría suave). Luego `circuit_model.dart` + pantalla a editar.

## Language

Match the user (usually Spanish).
