# Pantalla del M5 (RiderLab logger 0.5.0-anchor): qué se ve

Referencia para contestar "¿qué sale en la pantalla del ancla / del M5?" sin volver a leer el código.

- **Firmware:** `riderlab-logger 0.5.0-anchor` (`FIRMWARE_VERSION` en `hardware/firmware/include/HardwareConfig.h`).
- **Fuente:** el código de dibujo en `hardware/firmware/include/UiChrome.h` (pinta) y `hardware/firmware/src/main.cpp` (`fillAnchorUi()`, `paint()`, `loop()`), más `AnchorEngine.h`, `GnssService.h` y `PpsClock.cpp` para los textos de estado. Copia leída en LUJU3 el 8 oct 2026 a las 13:10 (hora de Zapopan).
- **Ojo:** todo lo de abajo sale del código y del log serial, **no de una foto** de la pantalla física.

---

## 1. Generalidades

| Cosa | Valor |
|---|---|
| Pantalla | 320 x 240 px, M5Stack Basic v2.7 |
| Fondo / texto | Fondo **blanco** (`C_BG 0xFFFF`) y texto **negro** (`C_FG`), pensado para usarse al sol |
| Naranja de marca / advertencia | `C_ORANGE` = `C_WARN` = `0xF9C0` (~#FF4B00) |
| Verde "bien" | `C_OK 0x06E0` (bloqueado, guardado, en rango) |
| Rojo | `C_REC 0xF800` (grabando, GNSS sin enlace, ancla movida) |
| Gris tenue | `C_MUTED 0x6B4D` (etiquetas secundarias) |
| Turquesa | `C_TEAL 0x07F4` (solo la etiqueta COLOC del rol rider) |
| Fuente | La de 6x8 px de M5GFX. `setTextSize(1)` da 6x8, `(2)` da 12x16, `(3)` da 18x24 y `(4)` da 24x32. Una línea de tamaño 1 cabe en ~52 caracteres. |
| Regla de color | `toneOk(x)`: verde si se cumple y naranja si no. Las líneas de estado (`toneStatus`) salen naranjas si contienen `fail`, `missing`, `Stop first`, `SIN` o `no wifi`, y verdes en cualquier otro caso. |

### Botonera (igual en todas las pantallas)
- **Posición:** franja inferior desde y=212 hasta 240, con una línea naranja arriba (y=212).
- **Botones:** tres cajas **negras con texto blanco**, de 98x20 px, en x=4, 111 y 218 (y=216).
- **Correspondencia:** cada caja queda justo encima del botón físico A, B o C.

---

## 2. Arranque

1. **Selector de rol (opcional).** Si mantienes **A+C** al encender:
   - Fondo blanco con `ROL DEL EQUIPO` (tamaño 2) y `Actual: ANCLA` o `Actual: RIDER (moto)`.
   - Debajo: `Suelta los botones y elige:` y `A = RIDER (moto)   B = cancelar   C = ANCLA`.
   - Botonera: `RIDER | CANCEL | ANCLA`.
   - Espera 15 s. Luego muestra `-> ANCLA` (naranja) o `-> RIDER` (negro) durante 1.2 s. El rol se guarda en la memoria del M5 (NVS).
2. **Splash:**
   - Fondo blanco y el ícono de RiderLab haciendo zoom (11 cuadros) centrado en (160,100).
   - Debajo, el wordmark **RIDER** en negro + **LAB** en naranja (tamaño 3, y=168) con una barra degradada de naranja a azul abajo.
   - `LOGGER` en gris (y=208).
3. **Línea de progreso.** Va abajo al centro, en gris (y~236). Muestra en orden:
   - `ROL: ANCLA` o `ROL: RIDER`
   - `GNSS…`
   - `GNSS config…`
   - `IMU…`
   - `BARO…`
   - `SD…`
4. **Escaneo de pines (opcional).** Si mantienes **B** al encender:
   - Pantalla **negra** con `PIN SCAN`.
   - Una fila por pin, como `G35 HI edges=1234` (HI = alguien transmite en ese pin; edges = cambios de nivel). Revisa los pines 0, 2, 5, 12, 13, 15, 16, 17, 19, 26, 34, 35 y 36.
   - Luego `I2C: 69 75 76` y `BtnA = continuar`. Espera hasta 8 s.
5. Después entra a la pantalla principal del rol.

**La versión NO se ve en la pantalla principal.** Solo aparece en Menú → ABOUT y en el log serial.

---

## 3. Rol ANCLA: pantalla principal

### 3.1 Encabezado (fijo; se redibuja al cambiar de página o al empezar o parar la grabación)

| Elemento | Posición | Aspecto |
|---|---|---|
| Ícono chico | (8,6) | Logo RiderLab |
| Wordmark `RIDERLAB` | Centrado en x=150, y=8, tamaño 2 | RIDER negro + LAB naranja, barra degradada debajo |
| Batería `NN%` | Arriba a la derecha, alineada a x=314, y=8, tamaño 1 | Verde si es >=20 %, naranja si es menor. Se actualiza en cada refresco. |
| Insignia **ANCLA** | Rectángulo naranja (246,22) de 70x18, texto blanco tamaño 2 | Fija mientras el rol sea ANCLA |

**En el rol ANCLA NO aparece la línea `GPS <sats>  <Hz>Hz` / `NO FIX`, ni el punto rojo `REC`.** Esas son del rol rider (sección 5). En el ancla, los Hz salen en la línea 1 de cada página (ver abajo) y el estado de grabación sale en el título de estado.

### 3.2 Zona viva (de y=46 a 209)
- **Título de estado:** tamaño 2, en (6,48), con color propio.
- **Líneas:** hasta 11, de tamaño 1, en x=6 y y = 68 + 13·i (i = 0…10, o sea de y=68 a y=198).
- **Color de cada línea:** negro, salvo las que se indican abajo.
- **Dibujo:** se pinta en un sprite de 8 bits, así que no parpadea.

### 3.3 Botones en el ancla (pantalla principal)

| Botón | Etiqueta | Acción |
|---|---|---|
| A | `REC` (parada) / `STOP` (grabando) | Inicia o detiene la sesión. Si la detienes a mano, el ancla **ya no se reinicia sola** (`DETENIDA (A=REC)`). |
| B | `MENU` | Abre el menú (sección 6) |
| C | `PAGINA` | Alterna entre la página 0 (POSICIÓN) y la página 1 (CALIDAD GNSS) |

En el ancla no hay MARK ni COLOC por botón; esos se mandan por serial (`MARK`, `COLOC START|END`).

### 3.4 Atenuación de pantalla (solo ancla)
- **Cuándo se atenúa:** tras **3 min sin tocar botones** (`ANCHOR_DIM_AFTER_MS = 180000`), el brillo baja a **12/255**. El contenido sigue ahí, pero casi no se ve al sol.
- **Refresco:** cada **0.5 s** normal y cada **2 s** atenuada.
- **Primer botón con la pantalla atenuada:** solo la **despierta**. Ese clic se descarta (o expira a los 2 s), así que no cambia de página ni arranca o detiene nada. Hay que volver a presionar.
- **Si detecta que movieron el ancla:** la pantalla se despierta sola para mostrar `ANCLA MOVIDA!`. Un golpe aislado **no** la despierta.

### 3.5 Página 0: POSICIÓN (la que aparece al arrancar)

**Título de estado.** Se evalúa en este orden y gana el primero que se cumpla:

| Condición | Texto | Color |
|---|---|---|
| GNSS sin enlace UART/I2C | `GNSS SIN ENLACE` | Rojo |
| Movimiento detectado (inclinación >1.5° sostenida 2 s), dura 120 s | `ANCLA MOVIDA!` | Rojo (además reinicia el promedio) |
| Golpe en los últimos 5 s | `GOLPE - NO TOCAR` | Naranja |
| No graba y la paraste tú | `DETENIDA (A=REC)` | Naranja |
| No graba todavía (espera el auto-inicio) | `ESPERANDO FIX` | Naranja |
| Graba y está lista | `REC mm:ss LISTA` | **Verde** |
| Graba y sigue estabilizando | `REC mm:ss ESTAB m:ss` (tiempo de grabación + cuenta regresiva de 3:00) | Naranja |
| Graba, no está lista por otra razón | `REC mm:ss <razón>` (ver la tabla de razones) | Naranja |

**Peculiaridad:** mientras no haya ni una época UBX "buena", la cuenta regresiva **se queda fija en `ESTAB 3:00`**. Pasa porque el código devuelve los 180 s completos si nunca hubo fix bueno. La razón real se lee en la línea 8 (`why:sin fix bueno`).

**Auto-inicio de grabación:**
- Arranca sola en cuanto hay fix (UBX 3D, o NMEA válido si no hay UBX).
- Si no hay fix en 5 min, arranca igual (`auto-nofix-baro`), porque la referencia del barómetro sirve de todos modos.
- Para que arranque, la SD tiene que estar OK y no la debes haber parado tú.

**Líneas de la página 0:**

| # | Formato exacto | Significado | Color |
|---|---|---|---|
| 0 (con UBX) | `fix %s sv %u pDOP %.1f hAcc %.2f vAcc %.2f` | Tipo de fix (`no`/`2D`/`3D`/`3D+DR`/`time`), satélites usados, PDOP, precisión horizontal y vertical estimadas (m) | Verde si el fix es 3D bueno y hAcc ≤ 2.00 m; naranja si no |
| 0 (sin UBX) | `NMEA fix %d sv %d (sin UBX: cfg %s)` | Fix NMEA 1/0, satélites NMEA y estado de la config. Aparece cuando el receptor no manda UBX (sin ruta de comandos). | Naranja |
| 1 | `N %lu  prom %02lu:%02lu  %uHz cfg %s` | **N** = muestras válidas promediadas; **prom** = tiempo promediando (mm:ss); **Hz** = épocas por segundo medidas; **cfg** = estado de la config del receptor | Negro |
| 2 | `media %.8f %.8f` o `media: (esperando muestras validas)` | Lat/lon promedio de la antena | Negro |
| 3 | `h elip %.2f  msl %.2f  ant %.2f` | Altura elipsoidal promedio, altura sobre el nivel del mar (con la separación del geoide del receptor) y ANT_H (m). Solo aparece si ya hay media. | Negro |
| 4 | `std E %.2f N %.2f U %.2f m` | Desviación estándar Este/Norte/Arriba de las muestras. Solo aparece si ya hay media. | Negro |
| 5 | `REF %.10s %s s=%.2f h=%s` o `REF: ninguna (serial REF ... o REF FROM AVG)` | Punto de referencia: id (10 caracteres), fuente, sigma (m), tipo de altura `msl`/`elip` | Negro, o **naranja** si no hay REF |
| 6 | `media-REF E%+.2f N%+.2f U%+.2f` | Diferencia promedio − REF (m). Solo aparece si hay REF y media. | Negro |
| 7 | `err %s E%+.2f N%+.2f U%+.2f` | Error de la última época: `REF` = contra el punto de referencia, `med` = contra la media | Negro |
| 8 | `med60-media %s  why:%s` | Distancia horizontal entre la mediana de los últimos 60 s y la media (`--` si no hay datos) y la razón de no-lista (`ok` si ya está lista) | Negro |
| 9 | `baro %.2f hPa %.1fC  IMU %s` | Presión (hPa) y temperatura del BMP280. IMU = `quieto`, `GOLPE` o `??` (si \|a\| está fuera de 7–12.5 m/s²). | Negro |
| 10 | `PPS %s  SD %s  WiFi off  %s` | PPS (`OK`/`unlocked`/`none`/`NOISE`), SD `ok`/`--`, Wi-Fi siempre apagado en el ancla y la última línea de estado (`ancla: esperando fix`, `Ancla grabando`, `Stopped`, …) | Verde si PPS y SD están OK; naranja si no |

**Razones de "no lista"** (`why`, en este orden de revisión):

| Razón | Qué significa |
|---|---|
| `sin fix bueno` | Nunca hubo una época UBX 3D con hAcc ≤ 3 m y ≥ 6 satélites. **Sin UBX nunca sale de aquí.** |
| `estabilizando` | Todavía no pasan los primeros 3 min desde el primer fix bueno (esas muestras no cuentan) |
| `pocas muestras` | N < 600 (60 s a 10 Hz) |
| `fix<3D` | La última época no es 3D |
| `hAcc alto` | hAcc > 2.0 m |
| `pocos sat` | Menos de 10 satélites |
| `golpe <60s` | Hubo un golpe en el último minuto |
| `MOVIDA` | Se detectó movimiento (el promedio se reinicia) |
| `media deriva` | \|mediana de 60 s − media\| > 1.0 m, o todavía no hay mediana |

**LISTA** = ninguna de las anteriores.

### 3.6 Página 1: CALIDAD GNSS (botón C)

**Título:** `CALIDAD GNSS`, en negro.

| # | Formato exacto | Significado | Color |
|---|---|---|---|
| 0 | `enlace %s  cmd %s` | **Enlace** = cómo llegan los datos del GPS: `rx35 38k LOCK`, `rx35 tx17 115k LOCK`, `i2c 0x42`, o `rx15 38k` mientras busca. **cmd** = ruta para mandarle órdenes: `i2c`, `uart-tx17`, `uart-tx15`, … o `none` | Negro |
| 1 | `cfg %s  %u Hz  baud %lu` | Estado de la config (`none`, `no-cmd-path`, `noack`, `partial`, `ok`), Hz medidos y baudios del UART | **Verde solo si cfg=ok**, naranja si no |
| 2 | `fw %s` | Versión de firmware del NEO-M9N, leída con UBX MON-VER; `?` si nunca contestó | Negro |
| 3 | `usados %u: G%u R%u E%u C%u J%u S%u` | Satélites usados en la solución, por constelación: G = GPS, R = GLONASS, E = Galileo, C = BeiDou, J = QZSS, S = SBAS | Negro |
| 4 | `C/N0 usados %.1f dBHz  rastreados %u` | Intensidad de señal promedio de los satélites usados y total de satélites rastreados | Negro |
| 5 | `UBX ok %lu bad %lu relink %lu` | Tramas UBX buenas, malas y re-enganches del enlace | Negro |
| 6 | `PPS %s n=%lu glitch %lu lag %ldms` | Estado del PPS, pulsos contados, falsos pulsos rechazados y retraso de la última PVT respecto al PPS (0 si no hay PVT) | Verde si PPS=OK |
| 7 | `IMU \|a\| %.2f tilt %.2f golpes %lu mov %lu` | Magnitud de la aceleración (~9.8 en reposo), inclinación respecto a la base (°) y contadores de golpes y movimientos | Verde si la IMU es sana (7 < \|a\| < 12.5) |
| 8 | `baro %s err %lu T %.1fC` | Barómetro `ok`/`--`, errores de lectura y temperatura | Negro |
| 9 | `pvt %lu err %lu baro %lu` | Registros escritos en la sesión: `pvt.ndjson`, `anchor_err.ndjson` y barómetro | Negro |
| 10 | `ses %.20s` | Primeros 20 caracteres del id de la sesión | Negro |

**Si no hay UBX**, esta página **no** muestra un texto alternativo. Muestra ceros: `fw ?`, `usados 0: G0 R0 E0 C0 J0 S0`, `C/N0 usados 0.0 dBHz  rastreados 0`, `pvt 0 …`. El aviso `NMEA fix … (sin UBX: cfg …)` solo aparece en la **página 0**, línea 0.

---

## 4. Valores de `cfg` y `cmd` (lo que más se pregunta)

| cfg | Significado |
|---|---|
| `none` | Todavía no intenta configurar (sin enlace) |
| `no-cmd-path` | El M5 **no puede mandarle órdenes** al receptor: no hay respuesta por I2C 0x42 ni por ningún pin TX probado (13, 15, 16, 17, 2, 5, 26, 12). El receptor se queda con la config de fábrica: NMEA a 1 Hz y **sin UBX**, así que el ancla **no promedia** (N=0). |
| `noack` | Sí hay ruta, pero el receptor no confirmó ningún cambio |
| `partial` | Confirmó algunos cambios, pero no todos |
| `ok` | Perfil aplicado: 10 Hz, multi-GNSS, UBX PVT/SAT/DOP. Es lo esperado. |

- **`cmd` / `path`:** `i2c`, `uart-txNN` o `none`.
- **En el log serial**, cuando todo funciona, se ve algo como `gnss: cfg ok path=uart-tx17 link=rx35 tx17 … LOCK hz=10`. **La ruta se escribe `uart-tx17`**, no `tx17`.

---

## 5. Rol RIDER (moto): diferencias

**Encabezado:**
- El wordmark va centrado en x=168.
- La insignia es **`RIDER`**: rectángulo **negro** (262,24) de 54x14 con texto blanco tamaño 1.
- La batería se ve igual que en el ancla.

**Zona viva** (refresco a 5 Hz, sin atenuación):

| Zona | Contenido |
|---|---|
| y≈58, izquierda | **Grabando:** círculo rojo + `REC` en rojo. **Parado:** `IDLE` en gris. |
| y≈58, derecha | **`GPS <sats>  <Hz>Hz`** en verde (formato `"GPS %d  %dHz"`, p. ej. `GPS 11  10Hz`) o **`NO FIX`** en naranja |
| y≈58, centro | Etiqueta **`COLOC`** turquesa (120,50) de 80x16, solo mientras la co-ubicación está activa |
| Centro (160,118) | **Velocidad** grande, tamaño 4: `%3.0f` en km/h, o `--` sin fix. Abajo, `km/h` en gris. |
| y=168 | Indicadores `IMU OK`, `BAR OK` y `SD OK`; cada uno en verde, o `--` en naranja si falla |
| y=182, x=10 | Etiqueta del enlace GNSS (p. ej. `rx35 38k LOCK`), verde si hay enlace o fix |
| y=182, x=120 | `WiFi ON`, `WiFi cfg` (configurado, sin conexión) o `WiFi off` |
| y=196 | Línea de estado (`Recording…`, `Stopped`, `Stopped 0 pts`, `MARK n`, `COLOC: junto al ancla`, `COLOC fin`, `cola N`, `subiendo N`, `Azure N`, `Stop first`, `Start fail: …`) |

**Botones del rider:**

| Botón | Etiqueta | Acción |
|---|---|---|
| A | `REC` / `STOP` | Inicia o detiene la grabación |
| B | `MENU` | Abre el menú |
| C | `SEND` (parado) / `MARK` (grabando) | **Parado:** sube a Azure por Wi-Fi. **Grabando:** clic = marca de vuelta o checkpoint (`MARK n` en la línea de estado). **Mantener 1 s** = activa o desactiva **COLOC** (moto junto al ancla para calibrar). |

**El rider no se atenúa.** El primer clic actúa directo.

---

## 6. Menú y pantallas secundarias (los dos roles)

- **MENU:** opciones `RECORD / STOP`, `WIFI`, `RIDES`, `ABOUT` y `BACK` (tamaño 2). La opción seleccionada va resaltada en naranja. Botones: `UP | OK | DOWN`.
- **ABOUT:**
  - Ícono grande y wordmark.
  - **`0.5.0-anchor`** en gris (y=168).
  - Abajo: `ROL: ANCLA  (serial ROLE RIDER)` en el ancla, o `A rec  B menu  C send/mark` en el rider.
  - Luego la etiqueta del enlace GNSS, verde o naranja.
  - Botón B = `BACK`.
- **WIFI:**
  - Título `WIFI`, la red guardada (o `(sin red guardada)`) y `CONECTADO` / `DESCONECTADO` / `SIN RED`.
  - Si está conectado: `IP …` y `RSSI … dBm`.
  - Una línea de estado y `ESP32 solo 2.4 GHz`.
  - Botones `CONN | BACK | SCAN`.
  - **En el ancla:** el Wi-Fi queda bloqueado (`ancla: WiFi off`) y SCAN no hace nada.
- **RIDES:**
  - `RECORRIDOS  N`, y hasta 5 filas `<id 8 car.>  <pts> pts` con `CLOUD` o `SD` a la derecha.
  - Si no hay sesiones: `Sin historial`.
  - Botones `UP | BACK | DOWN`.

---

## 7. Estado actual (8 oct 2026, 12:53)

> **Derivado del código y del último log serial de arranque, NO de una foto.** La pantalla física no se puede capturar desde aquí.

**Datos del log:**
- `riderlab-logger 0.5.0-anchor`, `ROLE=ANCHOR`.
- GNSS `link=rx35 38k LOCK`, `cfg no-cmd-path`, hz=1–2, 7–11 satélites, HDOP 2.14 → 1.38, PPS OK.
- `anchor n=0 ready=0 (sin fix bueno)`, REF none, ANT_H 0.000.
- Barómetro ~83887 Pa (838.87 hPa), 28 °C. IMU \|a\|≈9.82 (quieta).
- Grabación iniciada sola (`rec=1`, auto-fix). Sesión `a057d0c9-68be-00a6-c92d-d0c92df42a99`.

**Página 0 (POSICIÓN), como debería verse:**
```
[logo] RIDERLAB                                 NN%
                                          [ ANCLA ]   <- naranja
REC mm:ss ESTAB 3:00                                  <- naranja, 3:00 fijo
NMEA fix 1 sv 11 (sin UBX: cfg no-cmd-path)           <- naranja
N 0  prom 00:00  1Hz cfg no-cmd-path
media: (esperando muestras validas)

REF: ninguna (serial REF ... o REF FROM AVG)          <- naranja

err med E+0.00 N+0.00 U+0.00
med60-media --  why:sin fix bueno
baro 838.87 hPa 28.2C  IMU quieto
PPS OK  SD ok  WiFi off  Ancla grabando               <- verde
[  STOP  ] [  MENU  ] [ PAGINA ]
```
(`mm:ss` = tiempo desde el auto-inicio; sv varía de 7 a 11)

**Página 1 (CALIDAD GNSS), como debería verse:**
```
CALIDAD GNSS
enlace rx35 38k LOCK  cmd none
cfg no-cmd-path  1 Hz  baud 38400                     <- naranja
fw ?
usados 0: G0 R0 E0 C0 J0 S0
C/N0 usados 0.0 dBHz  rastreados 0
UBX ok 0 bad 0 relink 0                               (bad puede ser >0 por ruido)
PPS OK n=<pulsos> glitch 0 lag 0ms                    <- verde
IMU |a| 9.82 tilt 0.0x golpes 0 mov 0                 <- verde
baro ok err 0 T 28.2C
pvt 0 err 0 baro <crece ~10/s>
ses a057d0c9-68be-00a6-c
```

**En resumen:**
- El ancla **graba** (barómetro, IMU, NMEA y PPS), pero **no promedia ni llegará a LISTA**.
- La causa: sin ruta de comandos el receptor no manda UBX, y el promedio solo usa UBX NAV-PVT.
- Cuando el DIP RXD del M135 lleve el TX del M5 a G17 o G15, debería verse:
  - Página 1: `cmd uart-tx17` (o 15), `cfg ok` en verde y ~10 Hz.
  - Página 0: línea 0 `fix 3D sv …`, el contador `ESTAB` bajando de 3:00, y después N subiendo hasta `LISTA`.
- Al escribir esto, Juan ya había movido el DIP RXD y se estaba verificando un arranque nuevo. Actualiza esta sección cuando haya log.

---

## 8. Preguntas rápidas

**¿Dónde veo los Hz del GPS?**
- **Ancla:** página 0, línea 1 (`N … prom … <Hz>Hz cfg …`), y página 1, línea 1 (`cfg … <Hz> Hz baud …`).
- **Rider:** arriba a la derecha (`GPS 11  10Hz`).
- **Por USB:** `STATUS` o `GNSS` (`hz=`).

**¿El ancla muestra "GPS 11 10Hz" arriba como la moto?**
No. Esa línea solo existe en el rol rider. El ancla tiene la insignia ANCLA y la batería arriba; los Hz van en las líneas de las páginas.

**¿Cómo sé si el ancla está lista?**
- El título dice **`REC mm:ss LISTA` en verde** y la línea 8 dice `why:ok`.
- Si no, la razón está en la línea 8 (`why:…`) o en el título.

**¿Qué significa `cfg no-cmd-path`?**
- El M5 recibe datos del GPS, pero no le puede mandar órdenes.
- Por eso el receptor se queda a 1 Hz NMEA, sin UBX, y el ancla no promedia.
- Se arregla con el DIP RXD del M135 en G17 o G15 (nunca G0 ni G12).

**¿Por qué dice `ESTAB 3:00` y no baja?**
Porque nunca llegó una época UBX buena. Ver `why:sin fix bueno`. Se arregla junto con `cfg`.

**¿Dónde veo la versión del firmware?**
En Menú → ABOUT (`0.5.0-anchor`) o en el log serial. No aparece en la pantalla principal.

**¿Dónde veo cuántos satélites y de qué sistemas?**
- **Ancla con UBX:** página 1, línea 3 (`usados N: G R E C J S`).
- **Ancla sin UBX:** página 0, línea 0 (`NMEA … sv N`).

**¿Qué pasa si alguien golpea o mueve el ancla?**
- **Golpe:** `GOLPE - NO TOCAR` en naranja durante 5 s, y la razón `golpe <60s` durante 1 min.
- **Movimiento** (inclinación >1.5° por 2 s): `ANCLA MOVIDA!` en rojo durante 2 min. La pantalla se despierta y el **promedio se reinicia**.

**La pantalla está casi negra, ¿se apagó?**
- Lo más probable es que solo esté atenuada (3 min sin tocar).
- Presiona cualquier botón: el primer toque **solo la despierta**.

**¿Cómo cambio entre páginas del ancla?**
Con el botón C (`PAGINA`).

**¿Cómo cambio de rol?**
- Mantén A+C al encender y elige A=RIDER o C=ANCLA.
- O por serial: `ROLE RIDER` / `ROLE ANCHOR` (el M5 se reinicia).

**¿Dónde está la referencia (REF)?**
- Página 0, línea 5.
- Si dice `REF: ninguna` en naranja, falta mandar `REF lat|lon|h|fuente|sigma|id` o `REF FROM AVG` por serial (este último necesita N ≥ 600).

**¿La app del celular muestra los Hz del ancla o del M135?**
**No.** La app (`apps/mobile`) no se conecta al M5. Su chip de calidad GPS y su ficha "Hz" (`apps/mobile/lib/features/ride_detail/widgets/gps_quality_chip.dart` y `ride_detail_screen.dart`, campo `sampleRateHz`) son del **GPS del teléfono**, calculados de los puntos de la rodada.

---

*Para actualizar este documento: si cambia `UiChrome.h` o `fillAnchorUi()` en `main.cpp`, revisa las secciones 3 a 5. Si hay un log nuevo, actualiza la sección 7.*
