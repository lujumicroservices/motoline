# RiderLab off-road — plan

Variante de RiderLab para analizar circuitos de motocross y enduro. Circuito de record: **8 Horas Raceway**, Av. Las Torres, Paraísos del Colli, Zapopan. Meta de la empresa: el mapeo de circuito off-road más exacto que se pueda sostener con las herramientas más baratas que aún midan la pista.

Este documento no cambia código. Describe qué ya está en el repo, qué vive fuera, y en qué orden se construye la variante.

| Hecho | Dónde está |
|---|---|
| App de calle (grabación, mapa, curvas, social) | `apps/mobile`, `packages/ride_core` en `master` |
| Mapper de dos perímetros (borrador, no en `master`) | Draft PR **#3**, rama `cursor/offroad-circuit-map-6189`, base `exp/gps-track-points`. Lógica en `packages/ride_core` (`offroad_circuit.dart`) y pantalla en `apps/mobile/lib/features/circuit_map/` |
| Build **Circuito 8h** (borrador) | Draft PR **#4**, rama `exp/gps-track-points`. Paquete `com.rawthrottle.riderlab.c8h`, launcher Circuito 8h. No sustituye el APK de RiderLab |
| Skill de pista, sectores aún sin nombres del piloto | Draft PR **#1**, `mx-pilot/` |
| BOM Standard: M5Stack Basic Core v2.7 + módulo GNSS M135 (NEO-M9N, IMU BMI270, barómetro BMP280 en el módulo) | `hardware/BOM.md`, `DECISIONS.md`, `STATUS.md` (19 sep 2026). Precisión de línea esperada ~1–2.5 m, 10–25 Hz. El barómetro va en el módulo; la decisión cerrada es que no es requisito de producto |
| BOM Pro RTK, partes sueltas, ZED-F9P L1/L2 + base de paddock | Draft PR **#6**. ~$495/rover + ~$443 la base. Centímetros solo con RTK fixed |
| Comparación con AiM Solo 2 | Draft PR **#5**. Misma clase de sensor; el Solo 2 es el lap timer terminado |
| Firmware **Métrica** 0.6.x-circuit, archivo RLC1, suavizado, sectores y crops | Sin versionar, en la PC de Juan. Tag de circuito embebido `embedded-20261009-suave`, build **0.6.2-circuit.2**. Este plan lo cita; no lo importa |

Las figuras de referencia (antes/después del suavizado, y el crop del sector S1 sobre fondo negro) se generaron en ese mismo trabajo fuera del repo. No están en el árbol.

## 1. Geometría de referencia: el circuito suave

### Política

El circuito suave de **0.6.2-circuit.2** (`embedded-20261009-suave`) es la única geometría de referencia para todo lo que depende del dibujo de la pista:

- pantalla de circuito del M5
- sectores y gates estilo F1
- tiempos de vuelta y de sector
- análisis de curvas y de frenadas
- métricas de corredor (línea dentro del corredor, distancia a los bordes)
- vistas HD, vista 3D e imágenes de sector

El trazo crudo del 9 oct 2026 se conserva como capa opcional **«trazo crudo»**, solo para auditar el suavizado. No se usa para medir, cronometrar ni dibujar la pista por defecto.

### Levantamiento del 9 oct 2026

Dos loggers a pie, en el sentido de la rodada:

| Pase | Logger | Rol |
|---|---|---|
| Exterior | 3876 | Borde de afuera |
| Interior | a057 | Borde de adentro |

Resultado publicado en el firmware suave:

| Dato | Valor |
|---|---|
| Largo de vuelta (centerline) | 1370.3 m |
| Sectores (3, estilo F1, casi iguales) | 456.7 / 457.1 / 456.4 m |
| Ancho de corredor | 4.6–12.6 m, mediana 6.75 m |
| Desnivel del predio | ~16 m (el inset GPS+DEM del crop S1 va de 1730 a 1744 m) |
| Sentido | El crop de S1 está marcado CCW |
| Ancla | Primer fix GPS del pase de mapeo. La figura local está en metros desde meta |
| Archivo embebido | RLC1, ~2 KB: bordes exterior e interior, centerline, gates |
| Pantalla | 320×240, nombre de producto en el firmware: Métrica. Tema claro/oscuro en el M5 |

Los crops de sector ya se regeneraron sobre este mapa (primera versión, fuera del repo): cada sector maximizado y rotado, colores S1 rojo / S2 cian / S3 verde, pista gris `#808080`, coordenadas de gate, inset de elevación GPS+DEM, variantes transparente, negro y 320×240.

### Suavizado: paso estándar del pipeline

El método de 0.6.2 entra en toda captura nueva, no solo en este día:

1. Rechazo de outliers: mediana de vecinos, umbral **±6 m** en este pase M9N.
2. Remuestreo a **0.5 m** de longitud de arco.
3. Gauss periódico con corrección de sesgo **twicing** (no encoge el lazo; conserva las curvas).
4. Sigma por bisección hasta que **cada punto quede a ≤ 0.9 m del crudo**.

En este pase el solver dejó σ exterior **3.02 m** y σ interior **3.76 m**. Esos sigma son el resultado, no una constante para el siguiente sensor.

| Control | Este pase (9 oct) | Umbral para aceptar un suave nuevo |
|---|---|---|
| Desviación máxima vs crudo | 0.92 m exterior, 0.90 m interior | ≤ 0.9 m en cada punto |
| RMS vs crudo | 0.08 m exterior, 0.12 m interior | Registrar; muy por debajo del tope |
| Jitter de rumbo | 4.02→1.29 °/m y 5.84→1.31 °/m (3–4.5× menos) | Baja, y el lazo no se come curvas a simple vista |
| Área | Cambio < 0.1 % | < 0.1 % |
| Autocruces | 0 | 0 |
| Interior dentro del exterior | 100 % | 100 % |
| Ancho | 4.6–12.6 m, mediana 6.75 m | Dentro de banda física de esa pista (el mapper del PR #3 avisa < 3 m y > 60 m) |
| Cierre y largo | Vuelta 1370.3 m; sectores suman la vuelta | Cierre del anillo y suma de sectores = largo |

Trade-off conocido y aceptado: la horquilla exterior más cerrada queda **~0.9 m hacia adentro** de la punta cruda. Subir el tope de 0.9 m para “recuperar” esa punta se decide mirando el crudo, no automático.

Con RTK el mismo pipeline sigue, y el tope se aprieta al ruido del receptor. Un gauss de σ ≈ 3 m sobre una línea de centímetros borra bermas. El ±6 m y el tope de 0.9 m son del M9N de este pase.

El PR #3 guarda el trazo del teléfono sin este suavizado (punto cada ~3 m, tira fixes peores de 12 m). Esa salida es insumo. La referencia es el suave que pasa la tabla.

### Migración

| Componente | Antes (crudo) | Ahora (suave) | Estado |
|---|---|---|---|
| Pantalla de circuito del M5 | Bordes del pase crudo | RLC1 `embedded-20261009-suave` | Firmware 0.6.2-circuit.2 compilado; flash pendiente |
| Sectores y gates | Sobre el crudo | Sobre el suave. S1 rojo, S2 cian, S3 verde, pista `#808080` | Crops regenerados fuera del repo; la pantalla los toma al flashear |
| Tiempos de vuelta y sector | Geometría cruda | Gates del suave | Recálculo en curso |
| Curvas y frenadas | Motor de calle, o crudo | Contra el suave | Recálculo en curso |
| Corredor (línea, distancia a bordes) | Sin corredor de referencia | Ancho 4.6–12.6 m del suave | Geometría lista; métricas de rodada en recálculo |
| Imágenes HD / crops / vista 3D | — | Crops de sector ya sobre el suave | Crops listos fuera del repo. Vista 3D sin hacer. La app aún no consume el RLC1 |
| App Android | PR #3 y #4 guardan el GPS del teléfono | Debe leer el suave como referencia y ofrecer el crudo solo como capa | Pendiente de este plan |

## 2. Qué se reutiliza tal cual

La variante no reescribe el garage. Estas piezas de `master` sirven en tierra igual que en calle:

| Pieza | Dónde | Por qué se queda |
|---|---|---|
| Cuenta, términos, moto | `features/auth`, `legal`, ajustes | Identidad del piloto |
| SQLite offline, WAL, recuperación si se mata la app | `RideRecorder`, `motoline.db` | La pista no tiene señal de datos |
| Outbox y garage en Supabase | `packages/ride_core` sync, `RideSyncService` | El teléfono sigue siendo pits y sync |
| Grabación GPS + IMU + baro, servicio en primer plano | `RideRecorder`, `LocationService` (~10 Hz pedidos, filtro 40 m), `LeanSensor`, `BarometerSensor` | El flujo de captura es el mismo; cambian umbrales y la lectura, no el disco |
| Mapa post-rodada con `flutter_map` y teselas OSM | `pilot_line_map.dart` y pantallas de detalle | Base 2D. Hoy solo OSM (`tile.openstreetmap.org`); no hay DEM en la app |
| Scrub de la línea | Detalle del ride | Revisar una vuelta |
| Amigos, rodadas, fotos, Family Watch, reel | Features shipped | Social, ajeno a la geometría |
| Español / inglés | `app_es.arb` plantilla | |
| Contrato Gratis / Pro | `docs/FREE_VS_PRO.es.md` | Grabar y lo social siguen gratis. La profundidad de laboratorio es Pro cuando exista para tierra |
| Tests de `ride_core` + CI | `mobile-ci` | El suave y el corredor entran aquí como Dart puro, igual que huecos GPS |

`AppFeatures.routesEnabled` está en `false`: Rutas no se ve en la app que sale. El mapper del PR #3 cuelga de esa pantalla. La variante lo vuelve a abrir con el suave como entrada, no reactiva el producto de rutas de calle entero.

## 3. Qué se adapta a tierra

El motor de calle asume asfalto limpio, cielo abierto y una curva con radio. En 8 Horas el evento es berma, whoop, salto, rodera, piso suelto.

| Comportamiento de calle | Qué le pasa en off-road | Adaptación |
|---|---|---|
| Taxonomía `sweep` / `hairpin` / `chicane` / `doubleApex` (`docs/CURVE_TELEMETRY.md`) | Una berma no es una horquilla de asfalto; los whoops no son N curvas | Fases de tierra: aproximación, labio, aire, aterrizaje, berma, whoops, rodera. El motor de calle no etiqueta MX |
| Lean Lab Bugambilias (`v` alta, radio constante) | En tierra manda el pitch y el golpe, y el cuerpo no va con el chasis | Lean de MX solo con IMU en el chasis (BMI270). El teléfono en el bolsillo no se vende como skill de inclinación |
| Auto-pausa: 12 s bajo ~8 km/h, reanuda ~12 km/h (`MotionPatternDetector`) | Un whoop o una zona técnica a 5–15 km/h es rodada, no un alto | En circuito, la pausa automática de calle va apagada. Parar es meta, pits o un alto largo distinto |
| Filtro de teleport GPS | Un salto parece un hueco o un punto imposible | El hueco se conserva y se cruza con el IMU antes de tirarlo |
| Rampa de color de velocidad 25/45/65/90/130 km/h (`RideVizPalette`) | Techos de MX, no de autopista | Rampa propia de la pista, anclada a la velocidad real de la manga |
| Frenada = caída de velocidad GPS (`brake_detection.dart`) | Sigue siendo un proxy (no hay sensor de freno) y en tierra se mezcla con subida y peralte | Se conserva el proxy, medido sobre el suave y por sector, con la subida al lado para no llamar “frenada” a una cuesta |
| “Misma ruta” por bbox | El tractor rearma roderas el mismo día | La identidad es el RLC1 de esa fecha de pista, no un bbox de calle |
| Colores y tipo actuales | Legibles de noche en asfalto; pequeños al sol | Tema fijo de la sección 7. El M5 sí tiene Claro/Oscuro; la app de la variante no |

Multipath y árboles: el NEO-M9N y el teléfono se van bajo copa. El pase a pie del 9 oct ya eligió el borde; una manga en la misma zona necesita el chip de calidad GPS que la app ya muestra, más el estado de fix cuando haya RTK (NONE / FLOAT / FIXED). Vibración y lodo: la IMU va al chasis, no a la tapa de la pantalla; la caja del BOM es IP65 de prototipo. El lodo no cambia el algoritmo; cambia el montaje y obliga a repetir el pase si el logger se cae del borde.

## 4. Captura de perímetros

Orden que ya se usó y que queda como receta:

| Paso | Cómo | Notas |
|---|---|---|
| 1. Dos perímetros | Caminar o rodar el borde exterior y el interior, en el sentido de la pista, un logger por borde | Método de referencia. 9 oct: 3876 afuera, a057 adentro. El PR #3 y el PR #4 ya etiquetan interior/exterior |
| 2. Ancla y sentido | Primer fix del pase; orientación = dirección en que se mapeó | Así está armado el RLC1. Para clavarlo sobre una ortofoto hace falta coordenada de base en el mismo marco (el PR #6 lo dice para el F9P: el survey-in alcanza para comparar vueltas entre sí) |
| 3. Centerline | Eje entre los dos bordes suaves | No se camina aparte si los dos bordes existen |
| 4. Un solo centerline + ancho | Solo si falta un borde | Ancho constante es un borrador. En esta pista el ancho va de 4.6 a 12.6 m; un ancho único no es referencia |
| 5. Suavizado | Sección 1, con la tabla de QA | Paso obligatorio antes de publicar geometría |
| 6. Gates y sectores | Meta que cruza de borde a borde. 3 sectores por defecto, configurables, estilo F1 | Hoy 456.7 / 457.1 / 456.4 m. El PR #3 pide gate exterior+interior y sentido. El PR #4 marca start / finish / checkpoint con mediana de fixes quietos |
| 7. RTK, cuando haga falta bajar de ~1 m | Receptor externo. El Galaxy S25 Ultra no entrega fase de portadora | Elección operativa reciente, fuera del repo: base y rover **UM980**. El draft #6 escribe otro camino, **ZED-F9P** L1/L2 + radio 915 MHz, y sigue en borrador. Hasta cerrar uno, no se compran los dos |
| 8. QA | Tabla de la sección 1, más el checklist del PR #3 | Cierre ≤ 15 m, anillos que no se cruzan, bordes no invertidos, línea y gate dentro de la tierra, accuracy, espaciado, elevación presente, un segundo pase, un hito (torre, portón) para alinear |

Precisión por herramienta, en el mismo circuito:

| Herramienta | Horizontal que cabe esperar | Cuándo |
|---|---|---|
| Teléfono, gate del PR #4 | Espera ±4 m para grabar; “Record now” acepta hasta ±40 m. El radio que reporta el fused en exterior suele ser 3–5 m | Borrador y checklist. No es la referencia suave |
| M5 + NEO-M9N + antena (BOM Standard) | ~1–2.5 m, 10–25 Hz, cielo abierto | Referencia actual, ya caminada |
| F9P o UM980 sin correcciones | ~1.5 m CEP en el F9P del PR #6 | No justifica el costo |
| RTK fixed | Centímetros en banco; en moto, unos cm a ~10–20 cm (PR #6). Loguear tipo de fix y edad RTCM | Mapeo definitivo y línea de manga cuando el fijo se sostiene la vuelta |
| Drone (sección 6) | Ortofoto y DSM, no sustituye el eje GNSS | Relieve. La geometría de carrera sigue siendo el suave GNSS |

## 5. Métricas de rodada

Medido = sale de un sensor con una regla explícita. Estimado = proxy que se etiqueta como tal en la UI.

| Métrica | Quién la entrega | Medido o estimado |
|---|---|---|
| Tiempo de vuelta y de sector, mejor sector | Cruce de gate GNSS contra el suave, reloj del logger o del teléfono | Medido. El Métrica ya lo hace en pantalla |
| Vuelta teórica | Suma de mejores sectores | Estimada: esa suma puede no ser rodable en una sola vuelta |
| Línea contra el corredor | Posición GNSS vs bordes suaves: dentro/fuera, distancia a cada borde | Medida, con el error del receptor. Con M9N, un metro es ruido, no una trazada |
| Aire / detección de salto | IMU (BMI270 en el M5, o la del teléfono si va fija a la moto): baja-g sostenida + pitch. El hueco GNSS acompaña | Estimado. Sin IMU en el chasis no se publica |
| g de aterrizaje | Pico de aceleración vertical del IMU al cerrar el aire | Medido el pico; el “golpe bueno” es lectura del piloto |
| Ritmo de whoops / proxy de suspensión | Periodicidad de la aceleración vertical | Estimado. No hay sensor de recorrido de suspensión; es la respuesta de la moto, no la altura del whoop |
| Velocidad de entrada y salida de berma | Velocidad Doppler GNSS en las marcas del sector | Medida |
| Inclinación en la berma | Roll del IMU de chasis | Medida en el logger. En el teléfono de bolsillo, no se muestra |
| Puntos de frenada | Caída de velocidad GNSS (el detector de calle, reubicado al sector) | Estimado. No hay presión de freno |
| “Throttle on” | Subida de velocidad a la salida, después de quitar la pendiente del sector | Estimado. No hay TPS. El pitch de un salto no cuenta como gas |
| Subida y bajada por sector | Perfil del propio GNSS + baro a lo largo del arco. El inset actual es GPS+DEM | Medido el delta si el vertical del receptor aguanta el desnivel (~16 m en esta pista). El DEM de 30 m no entra en el número |
| Consistencia entre vueltas | Dispersión de tiempos de sector y de la línea dentro del corredor | Medida |
| Índice de rugosidad | RMS de aceleración vertical por tramo, o el DSM cuando exista drone | Estimado con IMU. Con DSM ≤ 0.5 m pasa a ser medida del terreno, y se etiqueta aparte del IMU |

El teléfono sigue guardando baro (`BarometerSensor`) y casi no lo usa como producto. En la variante el baro es delta relativo de sector, calibrado al arrancar en meta, no altitud absoluta.

## 6. Relieve e imagen de alta definición

### Fuentes

| Fuente | Resolución real | Exactitud | Licencia y uso | Para qué sirve aquí |
|---|---|---|---|---|
| SRTM 1 arcsec | ~30 m | Vertical de orden ~10 m | Dominio público (NASA) | Contexto regional |
| Copernicus DEM GLO-30 | ~30 m | Unos metros en cielo abierto; peor bajo bosque | Uso amplio con atribución Copernicus | Misma clase que SRTM, modelo más nuevo |
| Teselas Terrarium (AWS) | El render ya usado fuera del repo sale de aquí, a ~30 m. Un zoom más fino interpola; no inventa bermas | La del DEM de origen | Revisar el bucket concreto al cachear (suelen ser derivados de SRTM/Mapzen) | Lo que ya alimenta el inset GPS+DEM de Métrica. No está en `flutter_map` |
| INEGI CEM 3.0 | Rejilla ~15 m (confirmar la ficha el día de la descarga) | Mejor que 30 m, sigue sin ver un salto | Datos abiertos INEGI, con cita | Sustituto nacional del GLO-30 si el corte cae sobre 8 Horas |
| LiDAR y ortofoto INEGI, Jalisco | Por proyecto: densidad de puntos y año cambian. Las ortofotos de la ZMG suelen estar en decenas de cm/px, no en 5 cm | Útil si el polígono de Paraísos del Colli está cubierto | Datos abiertos, con cita. No vender el archivo como levantamiento propio | Comprobar cobertura antes de prometerla. Si no cubre la pista, no cuenta |
| Esri / Mapbox / otra ortofoto satelital | A menudo 30–50 cm/px en ciudad; peor en este predio | Imagen, no es un DSM. No mide altura de berma | Contrato comercial. Cachear offline dentro de la app solo si la licencia lo dice | Fondo visual, con atribución |
| Drone, fotogrametría | Ortofoto objetivo ≤ 5 cm/px. DSM objetivo ≤ 0.5 m (la fotogrametría puede más fino) | La que fijen los GCP o el RTK del drone | Propia, con permiso del predio | La opción HD de verdad |
| GNSS + baro propios, a lo largo del eje | Perfil 1D, no superficie. M9N vertical ruidoso (varios metros). RTK vertical ~1.5–2× el horizontal | El delta de ~16 m del predio sí se ve; una berma de 1–2 m no, con M9N | Propio | Número de subida/bajada. Verdad de campo para juzgar un DEM |

### Por qué 30 m no alcanza

La pista mide ~1.4 km y el corredor 4.6–12.6 m. Una berma o un salto es un objeto de **1–5 m** en planta y de 1–3 m de alto. Una celda de 30 m es más ancha que el corredor: labio y recepción caen en el mismo poste. El DEM de 30 m solo puede sugerir el lomo del predio (esos ~16 m, el inset 1730–1744 m).

Hace falta, sobre el bbox de la pista más un margen (el dibujo local cabe en unos 400×200 m; con margen son unas pocas hectáreas):

- DSM ≤ 0.5 m para que berma y salto existan como relieve
- Ortofoto ≤ 5 cm/px para ver rodera, labio y el borde que ya caminamos
- El eje suave GNSS encima, para no reemplazar la geometría de carrera por una foto

### En la app Android (2D)

`flutter_map` 8 ya está en el proyecto. El relieve entra como capa, no como app de mapas nueva.

| Capa | Formato | Presupuesto |
|---|---|---|
| Fondo de contexto | Hillshade o color de elevación, raster XYZ o MBTiles local | El bbox de unas hectáreas a zoom 16–17, JPEG, objetivo < 15 MB |
| Curvas de nivel | Vector generado offline del DSM, no del GLO-30 | Un GeoJSON chico, < 1 MB |
| Corredor y líneas | Polígonos del RLC1 suave, más vueltas coloreadas por velocidad | Encima del raster, opacidad del corredor para que el gris `#808080` se lea sobre el hillshade |
| Perfil | El mismo inset del M5: elevación vs metros de arco, por sector | Viene en el paquete del circuito, no de la red |
| Offline | MBTiles o GeoTIFF recortado al bbox, descargado en pits | Sin red en la manga el mapa de la pista sigue ahí. OSM puede faltar; el paquete local no |
| 3D | Sección 6.6 | Otra fase |

Una capa de 30 m se etiqueta con su fuente y su paso (“Copernicus 30 m”). No se deja que parezca un levantamiento de la berma.

### En el firmware

El M5 no carga un GeoTIFF. Métrica ya dibuja, por sector, el perfil GPS+DEM en 320×240. Para la variante se guarda un perfil diezmado junto al RLC1: cota vs arco, del orden de un sample cada 5–10 m, enteros en cm. Son unos cientos de bytes. Sirve para el inset y para el delta de subida/bajada. No sirve para la altura de un salto. El datum horizontal sigue siendo el primer fix (o la base RTK cuando exista). El perfil vertical va en metros ortométricos para que el inset coincida con el crop (1730–1744 m); la métrica usa el delta.

### Mejora con IA (y el límite)

El relieve de 30 m se ve borroso porque el dato es borroso. La IA puede afinar la **imagen**, y tiene que quedar marcada.

| Técnica | Qué haría | Dónde corre | Costo |
|---|---|---|---|
| Super-resolución de ortofoto, clase Real-ESRGAN o SwinIR (2–4×) | Más píxeles sobre una foto ya existente | Pipeline offline en PC o GPU de alquiler. Unas pocas hectáreas a 5 cm son decenas de megapíxeles: una noche de GPU, no un servicio en la app | Bajo y de una vez. Pesos abiertos |
| Super-resolución de DEM guiada por la ortofoto y por las cotas GNSS/baro del eje | Intentar romper la celda de 30 m usando bordes de la foto y el perfil que sí medimos | El mismo PC. El perfil GNSS es el control, no un adorno | Igual, una corrida por versión de pista |
| Inpainting | Tapar nubes, teselas faltantes y huecos bajo copa | El mismo PC | Igual |

Reglas:

- Toda capa que pase por esto se llama **«mejorado con IA»** en la UI y en el nombre del archivo.
- No entra en ninguna métrica: ni ancho, ni altura de salto, ni tiempos, ni distancia al borde. Esas siguen en el suave GNSS y, si hace falta superficie medida, en el DSM del drone.
- Validar el DEM mejorado contra el perfil GNSS/baro del eje. Si el residual a lo largo de la pista es mayor que el error vertical del propio GNSS, la capa no se publica ni como fondo.
- Bajo árboles el inpainting es la zona menos confiable, y es justo donde el GNSS también sufre. Ahí se prefiere repetir el pase o volar el drone.
- El modelo no va en el teléfono: peso, calor, y mezcla lo medido con lo inventado dentro del APK.

Cuando la cota importe, el camino es el drone (GCP o RTK de vuelo), no un modelo generativo.

### Vista 3D

Objetivo de producto: moverse por el relieve con el dedo, con la pista encima.

Controles: órbita, pinch de zoom, tilt, pan a dos dedos, replay que vuela la vuelta, tap en un sector para encuadrarlo, corredor y líneas proyectados sobre el terreno, vueltas coloreadas por velocidad.

| Opción | Qué da | En este teléfono | Cuándo |
|---|---|---|---|
| WebView + CesiumJS, terreno quantized-mesh propio | Cámara y terreno maduros. Cesium ion no hace falta si el mesh y la foto son nuestros | En un Galaxy S25 Ultra puede ir a 60 fps con este bbox chico. En gama media el WebView se queda cerca de 30. El puente JS complica el offline y el tema negro | Demo, no el objetivo de 120 Hz |
| Plugin `maplibre_gl` con terrain-RGB | 2.5D nativo, MBTiles offline, menos APK que un motor | Pan y pitch topan (~60–85°). No es caminar el suelo. Rinde mejor que el WebView | Fondo de relieve de la fase beta |
| Vista nativa Filament, o malla propia con Impeller | Órbita libre. Una malla de 0.5 m sobre ~10 ha son ~40k postes, ~80k triángulos: cabe en 60 fps | Gama media: bajar textura y quedarse en 30 fps como piso. Unity como librería suma decenas o cientos de MB al APK y no compensa este bbox | La vista 3D de producto |
| `flutter_scene` / un three.js embebido | El mismo mesh, menos maduro en Flutter hoy | Hay que medirlo; no se elige a ciegas | Solo si un spike de una semana bate a Filament en el S25 Ultra |

Presupuesto offline del paquete 3D, solo el bbox:

- Contexto 30 m (quantized mesh o terrain-RGB): < 5 MB
- Drone: JPEG de ortofoto + mesh, objetivo < 80 MB
- Nada de caché del mundo

Metas de frame: 60 fps en clase Galaxy S25 Ultra; 90/120 Hz si el mesh aguanta y el modo de pantalla de la sección 7 está activo. En gama media, 30 fps estables valen más que un 60 que se cae. El jank se nota más al sol, con el brillo alto.

## 7. UI de la variante Android

### Decisión — 2026-10-09 — tema sol de frente

En la app Android de la variante off-road el tema por defecto es la paleta de alto contraste para sol directo (**sol de frente**): fondo negro, colores de pista y de sector muy separados, tipo grande. **No hay selector de tema.** No se copia el toggle Claro/Oscuro que Métrica sí tiene en 0.6.2.

`apps/mobile` no tiene esa paleta. Lo que hay es `AppTheme.dark()` en `lib/theme/app_theme.dart`: Material 3, fondo carbón `#0E1013`, panel `#1A1E24`, texto `#F1F5F8`, secundario acero `#9BA4AE`, señal `#FF3D1F`, línea `#00D4AA`. Una sola función `dark()`; tampoco hay switch de tema en la app de calle. `RideVizPalette` es la rampa de calle (65/90/130). El acero `#9BA4AE` y los rótulos de 11–12 sp del HUD no aguantan sol de frente.

Requisitos de la paleta de la variante, mientras no exista en código:

- Fondo `#000000`. Paneles casi negros con borde de 1 px, sin sombra dura.
- Texto principal blanco. El texto secundario se queda claro (no bajar a `#9BA4AE`).
- Pista `#808080`. Sectores como los crops: S1 rojo, S2 cian, S3 verde, los tres legibles sobre negro y distinguibles entre sí con daltonismo (no apoyar el significado solo en el color; el sector lleva nombre).
- Una cifra principal por zona, grande, de un vistazo con el casco.

La app de calle puede seguir en `AppTheme`. La variante no ofrece cambiar a ese tema.

### Que toda la pantalla se vea actual

Principios para las pantallas de la variante:

- Rejilla de 4/8 dp, márgenes holgados (16–24 dp), no tablas apretadas.
- Jerarquía: una métrica primaria por zona. Tamaño, peso y contraste hacen el orden; el resto es secundario o no está.
- Un solo juego de iconos, trazo consistente: **Material Symbols Rounded**. Hoy se mezclan `Icons.*` filled y outlined con PNG (`ic_rodadas`, `ic_friends`, `ic_lean`, `ic_routes`).
- Componentes Material 3, que el `ThemeData` ya pide (`useMaterial3: true`).
- Movimiento corto (150–200 ms), sin rebote decorativo.
- Edge to edge, respetando insets del sistema.
- Fuera: biseles, gradientes pesados, sombras apiladas, skeuomorfismo, AppBar azul por defecto, texto diminuto, más de un estilo de icono.

### Tokens propuestos

No están en el código. Sustituyen los radios sueltos (4, 12, 14 y 16 dp conviven hoy) y las tres familias tipográficas.

| Token | Valor | Uso |
|---|---|---|
| `bg` | `#000000` | Scaffold |
| `surface` | `#141414` | Cards, borde `#3A3A3A` 1 px, elevación 0 |
| `text` | `#FFFFFF` | Primario |
| `textMuted` | `#E6E6E6` | Secundario, aún legible al sol |
| `track` | `#808080` | Corredor |
| `s1` / `s2` / `s3` | `#FF4D4D` / `#5CE1E6` / `#B6FF4D` | Sectores. Ajustar al hex exacto del firmware si el crop ya lo fijó |
| `radiusSm` / `Md` / `Lg` | 8 / 12 / 16 dp | Chips / botones / cards. El theme de calle ya usa 12 en botones y 16 en `cardTheme`; el 14 suelto desaparece |
| `space1`…`space5` | 4 / 8 / 16 / 24 / 32 dp | Todo margen y gap |
| `typeHud` | 56–72 sp, peso 600–700, cifras tabulares | Vuelta, sector, Δ |
| `typeTitle` | 22 sp / 700 | Títulos |
| `typeBody` | 16 sp | Mínimo de lectura |
| `typeLabel` | 13 sp | Piso. Hoy hay rótulos a 11 sp |

Tipografía. La app ya depende de `google_fonts` y pide **Exo 2** en el theme, **Rajdhani** en casi cada pantalla y **Barlow Condensed** en ajustes. Esas llamadas bajan la fuente en runtime; `pubspec.yaml` no embebe archivos de font.

Para la variante, dos familias embebidas, `allowRuntimeFetching = false`:

- UI: **Plus Jakarta Sans** (altura de x alta, lectura al sol).
- Cifras: **IBM Plex Sans**, cifras tabulares. Una sola familia de números en todo el HUD.

Ambas son OFL y se pueden meter en `assets/` en el build. Sin red, el tipo se ve igual.

Radios y botones: el theme de calle ya redondea; la variante solo usa los tres tokens.

Hz. Objetivo ≥ 60 fps en toda la variante. En pantallas de 90/120 Hz (Galaxy S25 Ultra y similares) pedir ese modo con `flutter_displaymode` o con el hint de frame rate de `Window` / `Surface` de Android. Hoy el proyecto no llama a ninguna de las dos. Impeller es el rasterizador por defecto en el SDK que ya pide el `pubspec` (`^3.11.1`); el build de la variante no lo apaga. Presupuesto: 16.6 ms a 60 Hz, 8.3 ms a 120 Hz. Perfilar el scrub, el pan del mapa y el replay antes de dar la fase por cerrada.

Parpadeo al sol: casi siempre es PWM del panel con el brillo bajo, no un frame perdido. Durante la rodada el brillo va alto o en automático al máximo. Eso se combina con el fondo negro: negro de tema, brillo de panel alto.

### Auditoría rápida de `apps/mobile`

La app de calle ya es Material 3 oscuro, no un AppBar azul. Lo que se ve viejo o frágil al sol es tipo chico, radios mezclados e iconos de dos familias. Arreglo por pantalla, cuando esa pantalla entre en la variante o comparta un widget:

| Pantalla | Qué choca | Arreglo |
|---|---|---|
| Home (`home_screen.dart`) | Cards a 14 dp, PNG de nav + Material icons, rótulos Rajdhani | Tokens de radio; un solo set de iconos; si el home de la variante existe, una acción primaria (armar / ver circuito) |
| HUD de rodada (`active_ride_screen.dart`) | Cifra de vuelta a 26 sp, stat a 28 sp, labels a 11 sp en acero `#9BA4AE` | Una cifra ≥ 56 sp (sector o vuelta); labels ≥ 13 sp en `textMuted`; rampa de color de la pista |
| Detalle y mapa | OSM pelado, rampa 65/90/130, lista de curvas de calle | Corredor suave + perfil; paleta de sectores; la taxonomía de calle no se muestra en esta variante |
| Skill Lab | Fases de curva de asfalto, replay denso | Fuera de la variante hasta que las fases sean aproximación / labio / aire / aterrizaje |
| Ajustes | Tres familias (Exo 2, Rajdhani, Barlow Condensed), 12 sp | Una familia, grupos con la rejilla de 8 dp. Sin fila de tema |
| Lean Lab | 11–12 sp, protocolo Bugambilias | No es pantalla de la variante |
| Rodadas / compare / rutas | Densidad de calle; rutas apagadas por flag | La variante no hereda esas pantallas. El circuito abre por el RLC1, no por Rutas de calle |

### Criterios de aceptación (UI)

- Cero controles de tema en la variante.
- Texto de rodada ≥ 13 sp; la métrica primaria ≥ 48 sp (objetivo de diseño 56–72).
- Texto primario blanco sobre `#000000`.
- Avión activado: las fuentes se ven, porque van en el APK.
- Solo radios 8/12/16 y spacings 4/8/16/24/32 en pantallas nuevas.
- En un S25 Ultra el modo de 120 Hz queda pedido durante el HUD y el mapa 2D; el frame time p95 cabe en el presupuesto. En un teléfono de gama media el HUD se mantiene a 60 fps.
- Brillo de rodada en alto. Revisión a pleno sol, no solo en el simulador.
- Fase: los tokens, el tema fijo, el tipo embebido y el hint de Hz entran en el **MVP**, limitados a las pantallas off-road. La pasada por las pantallas de calle de la tabla es **beta**, y solo donde compartan widgets.

## 8. Roadmap

### MVP — la pista suave en el teléfono

Entregables:

- Importar el RLC1 suave (bordes, centerline, gates, 3 sectores, perfil diezmado). Capa opcional de trazo crudo.
- Mapa 2D (`flutter_map`): corredor, sectores con sus colores, meta, perfil de elevación por sector. Teselas OSM si hay red; el circuito no depende de ellas.
- Tiempos de vuelta y sector al cruzar los gates del suave, mejor sector y vuelta teórica, leídos del log del M5 o calculados del GPS del teléfono.
- Grabación con la pausa automática de calle apagada en este modo. Huecos de GPS conservados.
- Tema sol de frente fijo, tipo embebido, tokens, hint de 90/120 Hz.
- Checklist de QA del suave visible, de solo lectura, para este circuito.

Hardware: los M5 que ya caminaron la pista (M135 + Basic v2.7). Flash de 0.6.2-circuit.2. Teléfono como UI.

Criterio de éxito: en una sesión en 8 Horas, la vuelta y los tres sectores del teléfono coinciden con Métrica dentro de un sample GNSS, el corredor es el de 1370.3 m y 4.6–12.6 m, y el HUD se lee al sol.

Riesgos: el flash no está hecho; el GPS del teléfono (3–5 m) es del orden del semiancho del corredor, así que “línea dentro” con el teléfono es grueso; el firmware sigue fuera del repo y el RLC1 hay que copiarlo a mano.

### Beta — pipeline en la app y relieve de contexto

Entregables:

- Portar el suavizado (outlier, 0.5 m, gauss+twicing, tope 0.9 m) a `packages/ride_core`, con tests de los umbrales de la sección 1, para que un pase nuevo produzca la misma clase de geometría.
- Métricas de la sección 5 que el M9N y el BMI270 ya pueden: línea vs corredor, frenada proxy por sector, subida/bajada, consistencia, aire y whoops si el IMU va en el chasis.
- Paquete offline de hillshade 30 m (Terrarium o GLO-30) + curvas gruesas, etiquetado como contexto. `maplibre_gl` solo si el hillshade de `flutter_map` no basta.
- Pasada de tokens en widgets compartidos con la calle.
- Nombres de sector del piloto cuando existan (≥3, como pide `mx-pilot`); mientras tanto S1 S2 S3.

Hardware: el mismo M5. Sin drone y sin RTK obligatorio.

Criterio de éxito: un segundo circuito (o un re-pase de 8 Horas) sale del pipeline de la app y pasa la tabla de QA; los saltos que el piloto anota coinciden con el aire del IMU en esa sesión; el hillshade no se usa en ningún número.

Riesgos: copiar mal el twicing y mover la horquilla más que 0.9 m; tratar el DEM de 30 m como berma; auto-pausa de calle colándose en el modo circuito.

### Pro — RTK, drone, 3D, IA marcada

Entregables:

- Un solo receptor RTK externo, el que se cierre (UM980 elegido en la operación reciente, o ZED-F9P del PR #6). Base en paddock, fix logueado. Re-pase de los dos bordes, suavizado con tope apretado al ruido RTK, nuevo RLC1 que reemplaza al de M9N como referencia.
- Vuelo: DSM ≤ 0.5 m y ortofoto ≤ 5 cm/px del bbox, empaquetados offline (< 80 MB).
- Vista 3D de la sección 6.6 (Filament o el spike que gane), corredor y vueltas sobre el DSM.
- Corrida de IA en PC, capa «mejorado con IA», validada contra el perfil GNSS, fuera de las métricas.
- Línea de manga a la precisión del fijo, no a la del teléfono.

Hardware: rover + base. Drone con GCP o RTK de vuelo. El M5 Standard puede seguir como display si se le alimenta la posición del rover; si no, el display es el del BOM Pro. No hace falta flota de 10 para cerrar la fase.

Criterio de éxito: dos pasadas RTK del mismo borde quedan dentro de la banda que el PR #6 ya publica para moto (unos cm a ~10–20 cm) en cielo abierto; el DSM muestra bermas que el piloto señala; la vista 3D sostiene 60 fps en un S25 Ultra con el paquete offline; ninguna métrica lee la capa de IA.

Riesgos: el fijo se cae bajo árboles y en la cara de un salto; 915 MHz del PR #6 no cubre la vuelta (pregunta abierta de ese PR); permiso de vuelo; licencias de ortofoto comercial si se mezclan con el vuelo; pantalla barata del BOM Pro ilegible al sol (el Basic v2.7 es de 853 nit; el panel de $20 del PR #6 no).

### Dónde cae cada extra

| Trabajo | Fase |
|---|---|
| Perfil GPS+DEM por sector, como el inset del M5 | MVP |
| Tema sol fijo, tipo embebido, tokens, 90/120 Hz en pantallas off-road | MVP |
| Suavizado dentro de `ride_core` + QA | Beta |
| Hillshade / color de elevación 30 m, MBTiles, offline | Beta |
| Curvas de nivel gruesas de contexto | Beta |
| Auditoría visual de pantallas de calle que compartan widgets | Beta |
| DSM y ortofoto de drone | Pro |
| Vista 3D con órbita y replay | Pro (un WebView Cesium puede demostrarse en beta; no cuenta como la vista) |
| Super-resolución e inpainting, etiquetados, en PC | Pro |
| RTK UM980 o F9P, tope de suavizado nuevo | Pro |

## 9. Decisiones

Fecha de las dos primeras: **2026-10-09**, día del pase y del tag `embedded-20261009-suave`.

1. **Geometría única.** Todo lo que depende del dibujo de la pista usa el suave 0.6.2-circuit.2. El crudo es capa de auditoría «trazo crudo».
2. **Tema de la variante Android.** Sol de frente, fondo negro, alto contraste, sin selector. Distinto del Claro/Oscuro de Métrica 0.6.2. `AppTheme` de la app de calle no es esta paleta.
3. **Dos perímetros** son el método de referencia. Centerline + ancho constante es borrador.
4. **El DEM de 30 m y cualquier capa «mejorado con IA» no son medición.** La medición de planta es el GNSS suave; la de superficie, un DSM de drone; la de tiempo, el cruce de gates.
5. **RTK no sale del Galaxy S25 Ultra** (no hay fase de portadora). Hace falta receptor externo. Cuál, sigue abierto entre el UM980 de la operación reciente y el ZED-F9P del draft #6.
6. Decisiones de `hardware/DECISIONS.md` que este plan no reabre: BOM Standard = M9N sin RTK y ~1–2.5 m; display sí; competidor de hardware AiM Solo 2; el prototipo es stack maker, no un dash sellado. El BOM Pro del PR #6 es un escalón aparte, todavía en borrador.

## 10. Preguntas abiertas

- ¿Se flashea 0.6.2-circuit.2 en los dos M5 antes de la próxima visita, o el RLC1 entra primero a la app por archivo?
- ¿La variante es un flavor al estilo Circuito 8h (`applicationId` aparte) o un modo dentro de RiderLab? El PR #4 ya separó el paquete para no pisar el APK de testers.
- ¿UM980 o ZED-F9P? Hace falta una línea en `hardware/` cuando se cierre. Hasta entonces no hay carrito Pro.
- ¿El piloto ya tiene nombres para los tres sectores, o siguen S1 S2 S3? `mx-pilot` (PR #1) deja la tabla vacía a propósito.
- ¿INEGI LiDAR u ortofoto cubren este predio, o el primer relieve fino es el drone?
- ¿El predio autoriza el vuelo, y quién pone los GCP?
- ¿La base RTK se queda en paddock a la vista (LoRa / radio) o hay NTRIP usable en Las Torres?
- ¿El teléfono de la manga va fijo a la moto? Si va en el bolsillo, el IMU de aire y de lean no se publica.
- ¿Quién recalcula tiempos y frenadas sobre el suave, el firmware en la PC de Juan o `ride_core`? Hoy el recálculo está en curso fuera del repo.
