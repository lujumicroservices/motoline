# Circuito 8 horas — contexto

## Qué es

Lab experimental en Ajustes: tile **Circuito 8 horas · A / B**.

Jerarquía: un proyecto → recorrido tipo A y tipo B → N pasadas cada uno. Cada pasada guarda fixes GPS para calibrar después. En la misma pantalla de pasada se marcan inicio, checkpoints (varios, borrables) y meta. Antes de grabar hay que elegir borde **interior** o **exterior**.

No es el logger de hardware (`hardware/`) ni el lab viejo de “grabar perímetro”.

## Para qué sirve

Input de encuesta del circuito real (Guadalajara, cielo abierto). Con esas pasadas se puede armar después un mapa de referencia y comparar recorridos de pilotos. Eso **aún no está implementado**.

## Decisiones cerradas

- Pasadas ilimitadas por tipo A y por tipo B. Guardar solo con ≥3 puntos.
- Inicio, meta y checkpoints en la pantalla de la pasada. Un inicio, una meta, N checkpoints.
- Cada pasada declara borde interior o exterior. Pasadas viejas pueden tener `edge` null.
- Precisión del lab: aceptar fix solo si accuracy ≤ **4 m**, el salto no es teleport, y el salto cuadra con la velocidad del teléfono (si la reporta y es ≥1 m/s). Ver `circuit_8h_precision.dart`.
- Marcador (inicio/meta/checkpoint): mediana de ≥3 fixes apretados que no se abran más de **6 m**. Hay que estar quieto.
- Si el piloto no espera el lock de 4 m, puede grabar igual hasta el tope de rodada (**40 m**). Eso es peor; no es el modo normal.
- El stream de rodada sigue en ~40 m. Este lab es más estricto a propósito.
- Subida a la nube: cuenta real (no anónima), dual-write a `ride_engine_labels` y telemetría. Ver DATA.md.
- Builds de este lab van en APK sideload aparte de master.
- **Altitud / relieve al grabar:** cada punto guarda `altM` (+ `altAccuracyM` si el OS lo da). Android pide MSL (`useMSLAltitude`). UI muestra alt actual, ↑climb ↓descent y min–max. Ruido vertical del teléfono suele ser peor que el horizontal (~10–30 m); sirve para relieve relativo, no cota topográfica.

## Lo que el teléfono no da

Fused location en exterior suele imprimir 3–5 m aunque el chip sea multi-banda. Centímetros = receptor externo o RTK. Antena del Chigee no alimenta el GPS del teléfono. Steren no vende un GNSS que mejore esto en un día. M5Stack M9N + antena (~1–2.5 m) es el escalón del proyecto de hardware, no un plan de emergencia.

## Mapeo 25 sep 2026

Descargado de `ride_engine_labels` (subida ~14:50 y ~15:55 hora local). Archivo: `docs/www/_dist/simm/circuit8h-2026-09-25.json`.

Grabaciones nuevas (14:01–14:47):

| Piloto | Ruta | Borde | Puntos | Marcadores |
|--------|------|-------|--------|------------|
| freck10 | A | exterior | 4646 | inicio + 17 checkpoints. Sin meta. |
| lujumicroservices | B | interior | 5690 | 18 checkpoints. Sin inicio ni meta. |

Precisión mediana ~3 m. Sin `altM`. La misma subida reenvió las pasadas del 24 sep (el teléfono manda el proyecto entero); esas polilíneas ya estaban en el HTML del 24. En ese reenvío freck etiquetó sus 3 A viejas como interior y luju las suyas como exterior.

Circuito dibujado (asfalto, no las polilíneas): `docs/www/_dist/simm/circuit8h-circuit.html`. Rebuild: `build_circuit8h_circuit.py`. GeoJSON: `circuit8h_circuit.geojson`.

Una pasada larga puede traer una vuelta interior y otra exterior. Se corta al volver al inicio y se clasifica por el lado del lazo. **Solo vueltas claras** dibujan el asfalto: interior offset <1 m, exterior >4 m, largo ≥1200 m. Mid-track (Garmin 3–6 ~1.5 m) y stubs cortos no entran. Ancho mediano **~6.8 m**.

| Trazo | Vuelta | Borde | ¿Usa? |
|-------|--------|-------|-------|
| 25 freck10 | 1 · 1513 m | exterior | sí |
| 25 freck10 | 2 · 1510 m | interior | sí |
| 25 lujumicroservices | 1 · 1385 m | interior | sí |
| 25 lujumicroservices | 2 · 1566 m | exterior | sí |
| Garmin Zapopan | 1 · 1608 m | exterior | sí |
| Garmin | 2 · 1396 m | interior | sí |
| Garmin | 3–6 | mid ~1.5 m | no |
| 24 freck10, las 3 A | una cada una | interior | sí |
| 24 luju A (~990 m) y B (~195 m) | — | short | no |

Método: `clear_edge_laps_robust_station_pct` (percentil robusto por estación + ancho 4.5–12 m). GPS ~3 m, no es el bordillo.

Si el trazo no coincide con el satélite: `docs/www/_dist/simm/circuit8h-adjust.html` — dibuja exterior/interior (guarda con **GUARDAR TRAZOS**); **Ajustar pista a mis trazos** pone el relleno azul exactamente sobre esos bordes (no warp del GPS). Rebuild: `build_circuit8h_adjust.py`.

Líneas crudas sobre satélite (ayer + hoy + carpeta `8horas`): `docs/www/_dist/simm/circuit8h-2026-09-25.html`. Rebuild: `build_circuit8h_lines_25.py`.

Carpeta `8horas` (25 sep):

| Archivo | Qué es |
|---------|--------|
| `activity_24498462887.gpx` | Zapopan Otros, 11:45–15:16, 5671 pts. Incluye el traslado desde 6 km y el circuito. El `.kml`, `.tcx` y `.csv` son el mismo activity (9.62 km); no se dibujan dos veces |
| `Track_AAAAAAAAAA 114503.gpx` | Garmin quieto 10:56–11:45, 567 pts, a 6 km. 5 puntos de 2024 en Taiwán no se dibujan |

Se quitaron `activity_24497851944.gpx` (Senderismo) y `activity_24498011072.gpx` (Motocicleta). Ya no entran al mapa.

## Mapeo 24 sep 2026

Dos pilotos subieron ese día. Resumen ya calculado:

| Piloto | Qué hay |
|--------|---------|
| freck10 | 3 pasadas ruta A (~15:25–15:40). Dejó **inicio**. |
| lujumicroservices | 2× A + 1× B. Una A es densa (1947 pts). Una pasada de 9 pts es prueba y se descarta. |

Totales útiles: **5 pasadas · ~3230 puntos**. Nadie subió meta ni checkpoints.

Centro aproximado del circuito: `20.6663, -103.4598`. El inicio de freck10: `20.6659498, -103.4604636`.

La pasada de 9 puntos está lejos (~20.72) y no es el circuito.

Esas pasadas **no traen borde** interior/exterior en el mapa exportado. A y B siguen sin definición física. **B (~196 m) es mucho más corta que A (~899 m)** — no asumir que B es el mismo layout completo.

### Camino (interior / exterior)

`docs/www/_dist/simm/circuit8h-road.html` — el asfalto, no las polilíneas GPS.

Las pasadas del 24 sep no traen `edge`. El camino es la envolvente entre la trazada más interior y la más exterior de 3 vueltas cerradas de freck10 (ruta A). Cada vuelta cierra cerca del inicio a **~1330 m** (la mediana vieja de ~899 m mezclaba pasadas sin alinear y no es el largo de la vuelta). Ancho mediano de esa envolvente **~5 m**, p90 **~10 m**. La pasada densa de lujumicroservices (~1000 m, no cierra) entra en la envolvente donde pisa el circuito. B no es esta vuelta.

Rebuild: `docs/www/_dist/simm/build_circuit8h_road.py`. GeoJSON: `circuit8h_road.geojson`.

Sigue siendo borrador de GPS de teléfono, no el bordillo.

### Mapa de referencia visual (borrador, 25 sep 2026)

Generado **sin tocar** el módulo Flutter `circuit_8h` (el remapeo en app sigue igual).

| Artefacto | Ruta |
|-----------|------|
| Viewer satélite (Esri) | `docs/www/_dist/simm/circuit8h-ref-map.html` |
| Pasadas crudas | `docs/www/_dist/simm/circuit8h_raw.geojson` |
| Centerline A/B + corredor ±12 m + start | `docs/www/_dist/simm/circuit8h_ref.geojson` |
| Resumen | `docs/www/_dist/simm/circuit8h_ref_summary.json` |
| Script rebuild | `docs/www/_dist/simm/build_circuit8h_ref.py` |

Fuente: `circuit8h-2026-09-24.html`. Método: mediana de 4 pasadas A; B = suavizado de 1 pasada. **Borrador visual** (GPS ~3–5 m), no centerline oficial.

**Sectores (provisionales):** gates cada ~150 m sobre centerline A (S0…SF) en el ref GeoJSON/viewer. **No** sustituyen meta/checkpoints de encuesta.

**Elevación DEM:** perfil ASTER 30 m vía OpenTopoData sobre A (~1727–1735 m, Δ≈8 m en el rebuild). Capas lean/saltos: schema en `circuit8h_analysis_layers.json` — esperan telemetría de rides (`awaiting_ride_telemetry`).

Mapa estático de pasadas crudas (OSM): `docs/www/_dist/simm/circuit8h-2026-09-24.html`.
También hay camino road: `circuit8h-road.html` / `build_circuit8h_road.py`.

Comparativa de trazadas (24 + 25 + `8horas/`): `circuit8h-2026-09-25.html` — chips on/off. Si un grabado trae vuelta interior y exterior (pasadas del 25 y Garmin Zapopan), se parten: **amarillo = interior**, **blanco = exterior**. Rebuild: `build_circuit8h_lines_25.py`.

## Código

| Archivo | Rol |
|---------|-----|
| `circuit_8h_models.dart` | Proyecto, sesión, punto, marcador, borde |
| `circuit_8h_store.dart` | SharedPreferences `circuit_8h_project_v1` |
| `circuit_8h_precision.dart` | Compuerta 4 m y mediana de marcador |
| `circuit_8h_elevation.dart` | Climb/descent/min/max desde `altM` |
| `circuit_8h_hub_screen.dart` | Lista A/B, borrar, subir |
| `circuit_8h_record_screen.dart` | Grabar una pasada (incluye altitud GPS) |
| `circuit_8h_markers_screen.dart` | Inicio / meta / checkpoints |
| `circuit_8h_cloud.dart` | Upsert Supabase |
| `circuit_8h_pass_view_screen.dart` | Ver una pasada |
| `test/circuit_8h_precision_test.dart` | Tests de la compuerta |
| `test/circuit_8h_elevation_test.dart` | Tests de relieve |

Entrada UI: `settings_screen.dart` → `Circuit8hHubScreen`.

## Siguiente

1. Validar `circuit8h-ref-map.html` (ref + sectores provisionales + perfil DEM).
2. Remapeo en app: meta, checkpoints reales, edges — luego regenerar gates oficiales (reemplazar provisionales) con `build_circuit8h_ref.py`.
3. Overlay de rides: tiempos por sector al cruzar gates; lean/saltos desde IMU del ride según schema en `circuit8h_analysis_layers.json`.

## Origen

Hechos de producto y del mapeo: chat [Circuito 8h A/B](273558cd-8ec6-4813-904b-02c1181f8674).
