# RiderLab: contexto de cambios (4–9 oct 2026)

Resumen factual de lo trabajado entre el 4 y el 9 de octubre de 2026, para usar como contexto en Cursor. Varias piezas viven fuera de este repo (indicado en cada caso). Horas en CST (America/Mexico_City).

## 1. Hardware y firmware de Métrica (M5)

"Métrica" es el nombre actual del dispositivo M5 de RiderLab: M5Stack Basic/Core v2.7 + módulo GNSS M135 (u-blox NEO-M9N, UART RX G16 / TX G12, 115200), IMU BMI270, barómetro BMP280 (BMM150 presente pero inactivo).

**El firmware NO está versionado en este repo.** Vive en la PC de Juan (LUJU3):
- Fuente original: `C:\Users\jvald\code\v1\hardware\firmware\` (sin tocar por estos cambios).
- Copias de trabajo: `v1-firmware-060-circuit`, `v1-firmware-061-circuit`, `v1-firmware-062-circuit`.
- Binarios, logs y scripts de verificación: `C:\Users\jvald\code\m5-circuit-060\`.
- Respaldo completo de flash (16 MB) de la unidad 3876 antes de 0.6.0: `flash_backup_7638_pre060_full16MB.bin`.

### Historial de versiones (unidad 3876, COM6, MAC f4:2d:c9:d0:76:38)
| Versión | Contenido |
|---|---|
| 0.5.5-rider-upfix | Corrige truncado de subida (quita tope `kGnssMax` de 24 KB), comando serial `REUP`, `requeueCloud()`, POST único JSON a Azure Function `logger-ingest`. |
| 0.6.0-circuit(.2) | Página de circuito: circuito embebido (formato RLC1, ~2 KB), anclado en el primer fix GNSS del mapeo, orientado por sentido de recorrido, sectores tipo F1 (3 por defecto), tiempos por sector/vuelta, mejor sector y vuelta teórica. Pista gris, bordes por color de sector. Menú "CIRCUITO". Memoria del circuito se libera antes de cualquier uso de Wi-Fi. |
| 0.6.1-circuit | Navegación por sectores (botón C: Mapa → S1 → S2 → S3 → tabla → Mapa): sector maximizado y rotado (S1 27°, S2 −9°, S3 27°), coordenadas lat/lon de puertas, perfil de elevación (GPS+DEM, 276 muestras cada 5 m), posición en vivo. Comandos serial `CIRCUIT S1..S4`, `CIRCUIT NEXT`, `CIRCUIT MAP`, `CIRCUIT SECTORS`. |
| 0.6.2-circuit | Tema Claro/Oscuro guardado en el dispositivo (NVS), conmutable desde el menú ("TEMA") y por serial `THEME DARK|LIGHT` / `THEME?`, sin recompilar ni reiniciar. Correcciones de redibujado bajo el punto en movimiento. Predeterminado deseado: Oscuro. |
| 0.6.2-circuit.2 | Usa el circuito suavizado (`CircuitEmbedded_suave.h`, tag `embedded-20261009-suave`). |
| 0.6.2-circuit.3 | Ícono nuevo de Métrica (wheelie) en arranque (96×96), About y encabezado (40×40). En Claro se dibuja como insignia negra con esquinas redondeadas. |
| 0.6.2-circuit.4 | **Instalado actualmente.** Relleno de pista naranja brillante (0xFC60 ≈ RGB 255,140,0) en todas las vistas y ambos temas; contorno negro en las líneas de sector y puertas; flechas de dirección negras; colores de sector S1 rojo, S2 cyan, S3 verde, S4 magenta (antes naranja). |

### Estado de 0.6.2-circuit.4 (flasheado 9 oct, ~23:15)
- Arranque: `RIDERLAB riderlab-logger 0.6.2-circuit.4 ROLE=RIDER hw=3876d0c92df4`, rides=24, pending=0, SD OK. `KEEPSD 1 (effective 1)`.
- Heap con página de circuito abierta: ~146 KB total, free8 ~103 KB, bloque mayor 63.5 KB (mínimos 60 KB / 40 KB).
- Tiempo de dibujo del mapa completo: ~181 ms (antes ~56 ms) por los contornos negros. Vistas de sector 134–158 ms, tabla 30 ms.
- Tema: el predeterminado de Métrica es **Oscuro** (decisión de Juan, 9 oct 2026); **Claro** se elige desde el menú. Nota: el código de 0.6.2-circuit.4 aún arranca en Claro cuando no hay preferencia guardada; falta cambiar ese valor por defecto a Oscuro en el firmware. La unidad 3876 ya está en Oscuro.
- **Pendiente:** probar en exterior con fix GNSS el punto en vivo, la estela, el marcador de elevación y el redibujado naranja bajo el punto (todas las pruebas fueron en interior, fix=0). Confirmar visualmente el ícono wheelie en pantalla.
- La segunda unidad (a057, COM8) no se ha flasheado con 0.6.x.

## 2. Mapeo del circuito (9 oct 2026)

- Dos unidades grabaron el mismo recorrido de mapeo (14:49–15:10): **3876 = borde exterior**, **a057 = borde interior**. Las vueltas del piloto (a169, b029, a7e7) van dentro del corredor.
- Datos descargados de Azure (`logger-ingest`); a057 se bajó directo de la memoria del equipo. Exportaciones en la PC: `C:\Users\jvald\code\riderlab-rides-export\export-20261009\`.
- Mapas Leaflet (satélite Esri por defecto; OSM se bloqueaba desde `file://`), editor interactivo de bordes, canales por rodada (velocidad, frenadas, inclinación estimada desde GPS, altitud GPS), gráficas y CSV.
- Vista aérea HD (4K/1080p) y vista 3D (PNG e interactiva). Elevación: GPS promediado en 5 pasadas + DEM AWS Terrarium (~30 m, r=0.78); **no hay datos de barómetro** de estas rodadas fuera de las SD. Desnivel real ~16 m.
- Recortes por sector maximizados (S1 rojo, S2 cyan, S3 verde) con coordenadas e inserto de elevación, en variantes con satélite, negro, transparente y 320×240.

### Suavizado de bordes
Los bordes crudos se veían como "trazo de niño"; se suavizaron ambos (3876 y a057):
1. Rechazo de outliers (mediana de vecinos ±6 m): 5 puntos exterior, 10 interior.
2. Remuestreo cada 0.5 m por longitud de arco (lazo cerrado).
3. Gaussiano periódico con corrección de sesgo (twicing), fuerza máxima tal que ningún punto se aleje más de 0.9 m del crudo (σ 3.02 m exterior, 3.76 m interior).

Resultado: RMS 0.08/0.12 m, máx ~0.9 m; jitter 4.02→1.29 y 5.84→1.31 °/m (3–4.5× menor); área ±0.1 %; 0 autointersecciones; interior 100 % dentro del exterior; ancho 4.6–12.6 m (mediana 6.75 m). Vuelta 1374.9 → 1370.3 m; sectores 456.7 / 457.1 / 456.4 m. Compromiso: en la horquilla exterior más cerrada la línea suave queda ~0.9 m dentro de la punta cruda.

**Decisión (9 oct, 22:33):** el circuito suavizado es la única geometría de referencia (pantalla del M5, sectores, tiempos, frenadas/curvas, corredor, vistas HD/3D). El trazo crudo queda solo como capa opcional de auditoría. Tiempos por sector recalculados: cambios de −0.21 a +0.34 s; mejor S2 b029 73.04 s, mejor S3 a169 66.84 s; vuelta teórica no calculable (ninguna vuelta cruzó la meta lanzada).

## 3. App Android RiderLab (apps/mobile)

- En el teléfono (Galaxy S25 Ultra) estaba **1.37.24-exp8 (versionCode 998)**, build sideload de la rama `exp/gps-track-points`.
- Se compiló e instaló **1.37.24-exp9 (versionCode 999)** el 9 oct a las 23:22, desde el commit `4ebc81a` de `exp/gps-track-points` ("Show a solid cancel control and record the track edge.", 12 commits por delante de `origin/master`) **más cambios sin commitear** de la PC de Juan en `apps/mobile` (emparejamiento de logger / pantalla de hardware Métrica, archivo de elevación circuit_8h, branding motocross, dependencia nueva `file_picker`). Esos cambios no están commiteados ni subidos.
- No se compiló `master` porque su versionCode (99) es menor y sería un downgrade.
- Comando: `flutter build apk --release --flavor sideload --build-name=1.37.24-exp9 --build-number=999 --dart-define=BUILD_LABEL=exp-gps-track-points` en un worktree aparte (`C:\Users\jvald\code\v1-app-exp9-build`), sin tocar el checkout `v1`.
- El primer build falló por falta de `google-services.json` en el worktree; se copió y el segundo build pasó.
- Instalado con `adb install -r` (misma firma), sin desinstalar: las rodadas locales en SQLite se conservaron. La app abrió sin errores.
- Se descartó (por decisión de Juan) un tema claro/oscuro en la app; ver el plan off-road para la decisión de tema.

## 4. Documentos y otros entregables

- Plan de la variante off-road: `docs/plan-riderlab-offroad.md` (PR #7, borrador): reutilización de RiderLab, adaptación a off-road, captura por dos perímetros (en backlog, fuera de alcance) con suavizado obligatorio, métricas, relieve HD (DEM/ortofoto/LiDAR/drone), mejora con IA etiquetada, vista 3D táctil, modernización de UI (esquinas redondeadas, tipografía moderna, ≥60 Hz), y la decisión de tema "sol de frente" (fondo negro, alto contraste, sin selector) para la app.
- Diseño de case imprimible (FDM, OpenSCAD) para el stack M5 + M135 + batería, con montajes manubrio/tanque/chasis y archivos Bambu Studio (fuera del repo, en la caja de trabajo del asistente).
- Investigación de GNSS RTK: el S25 Ultra no entrega fase de portadora; se eligió Unicore UM980 como base/rover (LC29HEA y ZED-F9P como alternativas). BOM Pro en PR #6 (en backlog, fuera de alcance).
- Datos de rodada y mapas HD/3D enviados por correo (9 oct) a sometimesmx@gmail.com y a Iván (suntimesmx@gmail.com).

## Backlog: fuera de alcance (out of scope)

Decisión del 9 oct 2026: estos tres ítems pasan a backlog, quedan fuera de alcance y no son trabajo activo.

1. Prototipo M5Stack base (BOM Standard): GPS NEO-M9N, ~US$128 en partes, precisión esperada 1–2.5 m. En este repositorio no hay firmware versionado para ese prototipo; el trabajo de firmware descrito en la sección 1 vive sin versionar en la PC de Juan. El firmware activo de Métrica (0.6.x-circuit) no forma parte de este backlog.
2. Mapeador de circuitos off-road por ambos perímetros — PR #3 (borrador).
3. BOM Pro con GPS RTK (u-blox ZED-F9P) — PR #6 (borrador).
