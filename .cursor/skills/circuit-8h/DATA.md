# Circuito 8 horas — datos

## Dónde está cada cosa

| Qué | Dónde |
|-----|--------|
| Copia en el teléfono | SharedPreferences `circuit_8h_project_v1`. Última subida: `circuit_8h_last_upload_at` |
| JSON completo (proyecto y cada pasada) | `public.ride_engine_labels` donde `phone_mount = 'circuit_8h'` |
| Aviso corto de telemetría | `camera_events`, category `circuit_8h`. El proyecto va completo; la pasada solo lleva conteo, no la polilínea |
| Mapa ya exportado del 24 sep | `docs/www/_dist/simm/circuit8h-2026-09-24.html` (variable `DATA`) |
| Pasadas nuevas del 25 sep | `docs/www/_dist/simm/circuit8h-2026-09-25.json` |
| Líneas 25 sep + GPX Garmin | `docs/www/_dist/simm/circuit8h-2026-09-25.html` (`build_circuit8h_lines_25.py`) |
| Circuito (interior/exterior, vueltas partidas) | `docs/www/_dist/simm/circuit8h-circuit.html` + `circuit8h_circuit.geojson` (`build_circuit8h_circuit.py`) |
| Comparativa satélite / circuito | `docs/www/_dist/simm/circuit8h-compare.html` (`build_circuit8h_compare.py`) |
| Ajuste visual / trazo manual | `docs/www/_dist/simm/circuit8h-adjust.html` (`build_circuit8h_adjust.py`). Dibujar líneas correctas → calcular desviación → pines; descarga GeoJSON o `circuit8h-pins.json` |
| Tracks en `8horas/` | `activity_24498462887.gpx` (Otros) y `Track_AAAAAAAAAA 114503.gpx`. KML/TCX/CSV de ese activity repiten el GPX |
| Camino interior/exterior | `docs/www/_dist/simm/circuit8h-road.html` + `circuit8h_road.geojson` |
| Mapa referencia visual (borrador) | `docs/www/_dist/simm/circuit8h-ref-map.html` + `circuit8h_ref.geojson` / `circuit8h_raw.geojson` |
| Sectores provisionales + DEM + schema lean/jump | `docs/www/_dist/simm/circuit8h_analysis_layers.json` |
| Rebuild referencia | `docs/www/_dist/simm/build_circuit8h_ref.py` (lee el HTML del 24 sep; no escribe la app) |

RLS: cada usuario solo lee sus filas. La clave anon no ve el mapeo. Hace falta sesión del piloto o rol que pase RLS.

## Esquema `circuit_8h.v1`

Proyecto (`notes = circuit_8h:project`, `ride_local_id = circuit_8h_project_v1`):

- `kind: project`
- `name`, `sessions[]`, `start`, `finish`, `checkpoints[]`

Pasada (`notes = circuit_8h:pass:a|b`, `ride_local_id = circuit_8h_pass_{sessionId}`):

- `kind: pass`
- `session`: `id`, `routeType` (`a`|`b`), `edge` (`inner`|`outer` o ausente), `startedAtMs`, `endedAtMs`, `points[]` de `{lat, lng, tsMs, accuracyM, altM?, altAccuracyM?}`
- Copia de `start`, `finish`, `checkpoints` del proyecto en ese momento (`altM?` en markers si se midió)

Pasadas del 24 sep **no** traen `altM` (grabadas antes). Las nuevas sí.

Conflicto de upsert: `(user_id, ride_local_id)`.

## Consulta práctica

Filtrar por mount, no por nombre de tabla inventada:

```sql
select user_id, ride_local_id, notes, labeled_at,
       payload->>'kind' as kind,
       payload->'session'->>'routeType' as route,
       payload->'session'->>'edge' as edge,
       jsonb_array_length(coalesce(payload->'session'->'points', '[]'::jsonb)) as points
from public.ride_engine_labels
where phone_mount = 'circuit_8h'
order by labeled_at;
```

Para geometría, leer `payload->'session'->'points'` (o `DATA.tracks` en el HTML del 24 sep). Descartar la pasada de prueba de 9 puntos.

## Qué no hacer

- No tratar `camera_events` como la polilínea.
- No mezclar estos `ride_local_id` con rodadas reales.
- No volver a pedir el inventario del 24 sep si CONTEXT.md ya lo tiene; sí reconsultar si el usuario dice que subió pasadas nuevas.
