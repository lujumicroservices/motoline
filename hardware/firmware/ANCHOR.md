# Modo ANCLA (estación de referencia) — M5Stack Basic + M135

Firmware `riderlab-logger 0.5.0-anchor`. **Un solo firmware, dos roles** guardados en NVS:
`RIDER` (moto, por defecto) y `ANCHOR` (ancla estática sobre un punto marcado del paddock).
Ambos roles aplican **la misma configuración del receptor**, condición para que la corrección
cancele el error común.

> Límite físico: el NEO-M9N es L1 sin fase portadora (no RTK). Estimado: 0.5–1 m absoluto
> (con REF medida), 0.3–0.7 m en forma promediando vueltas. La vertical GNSS sola no sirve para
> saltos; la altura fina sale de la **barometría diferencial** (abajo).

## Cómo funciona

- **Posición**: `err_ancla(t) = pos_ancla(t) − (REF + ANT_H)`; `moto_corr(t) = moto(t) − suavizado(err_ancla)(t)`.
  Solo cancela lo común: mismo receptor/perfil, antena y plano de tierra parecidos y **mismos satélites**
  (se registra NAV-SAT en ambos para comprobarlo).
- **Altura**: el ancla quieta mide la deriva de presión del clima. Altura de la moto respecto al
  ancla: `dh = (Rd·T/g)·ln(p_ancla / (p_moto − dp_coloc))`, anclada a la altura del punto (REF) y
  fusionada con GPS (baro = corto plazo, GPS/ancla = nivel de largo plazo).

## Perfil del receptor (ambos roles, `HardwareConfig.h`)

GPS+GLONASS+Galileo+BeiDou+QZSS+SBAS, 10 Hz (`CFG-RATE-MEAS 100 ms`), modelo dinámico
automotive (4), máscara 10°, SBAS ranging+diffcorr. Salidas UART1: UBX NAV-PVT cada época,
NAV-SAT y NAV-DOP ~1 Hz, NMEA GGA/RMC 1 Hz; UART a 115200. Se aplica con UBX-CFG-VALSET en
capa RAM en cada arranque (claves verificadas contra la descripción de interfaz u-blox M9) y se
revisa con VALGET para no reiniciar el GNSS si ya coincide.

**Ruta de comandos al receptor**: I2C DDC 0x42 si responde (en el M135 el bus I2C del host
solo ve BMI270 0x69 y BMP280 0x76; el DDC del NEO normalmente no aparece); si no, el firmware busca un pin TX
del ESP32 hacia NEO_RXD mandando `UBX-MON-VER` y esperando la respuesta en RX (G13/15/16/17/2/5/26/12),
y lo guarda en NVS. **Sin ruta de comandos el receptor queda en su configuración de fábrica** (1 Hz,
solo NMEA): la pantalla/manifest muestran `cfg no-cmd-path`. Revisa el banco TXD del DIP del M135 (TX del host → NEO_RXD: G17/G15/G12).

## Flasheo (mismo firmware en moto y ancla)

```bash
cd hardware/firmware
python -m platformio run
python -m platformio run -t upload --upload-port COM8   # ancla en LUJU3
```

> El 0.4.9-log decía "GPS-only 25 Hz" pero nunca enviaba la configuración: el receptor corría
> de fábrica (1 Hz NMEA). Moto y ancla deben llevar **0.5.0-anchor** para tener el mismo perfil.

## DIP medido (unidad ancla, 2026-10-08)

Banco **RXD→G16** (host RX), banco **TXD→G12** (host TX, `path=uart-tx12`), **PPS→G34**.
Nombres del silkscreen = lado receptor. G12 arranca bien en este Basic; si otro no arranca, TXD→G17/G15.

## Activar el rol

- Serial (115200): `ROLE ANCHOR` (o `ROLE RIDER`). Se guarda y reinicia.
- Botones: encender con **A + C presionados** → pantalla de rol: A = RIDER, C = ANCLA, B = cancelar.
- Se ve en el arranque serial (`==== RIDERLAB ... ROLE=ANCHOR ====`), en la pantalla (insignia
  naranja **ANCLA**) y en `manifest.json` (`"role":"anchor"`).

## Uso en pista

1. Stack igual que la moto (Basic + M135 + Battery + Bottom Base switch=0), SD puesta.
2. Antena sobre plano de acero de 10–12 cm, centrada, sobre la marca del paddock. Mide la altura
   antena–marca y mándala: `ANT_H 1.52`.
3. Coordenada del punto: `REF <lat>|<lon>|<h>|<fuente>|<sigma_m>|<id>[|ell|msl]`
   (ej. `REF 20.66594980|-103.46046360|1712.345|ppp|0.30|P1|ell`). Altura de la **marca** (no la
   antena); CSRS-PPP da altura elipsoidal (`ell`). Sin coordenada medida: deja promediar ≥1 min
   (mejor 2–4 h) y `REF FROM AVG` → origen local (`source=avg`, sirve para forma/relativo, no absoluto).
4. Enciende el ancla ≥10 min antes de rodar. **Arranca sola** al tener fix 3D (o a los 5 min sin
   fix, para que al menos quede la presión de referencia). Tras un corte de energía crea sesión
   nueva enlazada (`prev_session`).
5. Pantalla (A = REC/STOP, B = menú, C = página posición/calidad):
   N, tiempo promediando, media lat/lon/h, std E/N/U, media−REF E/N/U, error actual, hAcc/vAcc,
   sats, PPS, SD, batería, baro, IMU. Estado: `ESTAB m:ss` (3 min) → `LISTA` cuando: hAcc ≤ 2 m,
   ≥10 sats, ≥600 muestras, sin golpes en 60 s y mediana(60 s)−media < 1 m.
6. **No tocar**. Golpe (IMU) → `GOLPE - NO TOCAR`, el tramo se marca inválido (no entra al promedio,
   `dist=1` en `anchor_err`). Inclinación sostenida >1.5° → `ANCLA MOVIDA!`: reinicia el promedio.
7. Pantalla se atenúa a los 3 min (el primer botón solo despierta). Wi‑Fi apagado en rol ancla
   (no sube a la nube; la sesión se queda en la SD).
8. **Co-location (barómetros)**: al inicio y al final pon la moto 2–3 min junto al ancla sobre el
   punto. En la moto mantén **C 1 s** para marcar `COLOC` (otra vez C 1 s para terminar). C corto
   en la moto grabando = `MARK` (puntos de control/conos).
9. Moto: 5–10 vueltas con línea constante; sesión < 20–30 min por tramo de corrección.
10. Sensor baro: puerto **protegido del viento pero ventilado** (no sellado, sin chorro de aire
   directo); el viento a velocidad añade presión dinámica (≈ v²/2g ≈ 7 m a 43 km/h si entrara
   de frente).

## Coordenada del punto

Mejor a peor: topógrafo (1–2 cm) > S25 Ultra crudo 4–6 h a CSRS-PPP (0.2–1 m, no verificado) >
promedio NEO-M9N 2–4 h (0.5–1.5 m, `REF FROM AVG`). Si no es mejor que 0.5 m, úsala como origen
local. Para centímetros hace falta fase portadora (LC29HEA ~US$120/unidad + base UM980 ~US$200).

## Comandos serial

| Comando | Qué hace |
|---|---|
| `HELP`, `STATUS`/`ANCHOR` | ayuda / estado del ancla, receptor y PPS |
| `ROLE`, `ROLE ANCHOR`, `ROLE RIDER` | ver / cambiar rol (reinicia) |
| `ANT_H <m>` | altura antena sobre la marca |
| `REF <lat>\|<lon>\|<h>\|<fuente>\|<sigma>\|<id>[\|ell\|msl]`, `REF?`, `REF CLEAR`, `REF FROM AVG` | punto de referencia |
| `AVG RESET` | reinicia el promedio |
| `MARK [texto]`, `COLOC START`, `COLOC END` | marcas en `marks.ndjson` |
| `KEEPSD ON\|OFF` | (moto) no borrar la sesión de la SD tras subirla |
| `GNSS`, `GNSSCFG`, `PINSCAN`, `IMU`, `BARO` | diagnóstico / reconfigurar receptor / escaneo de pines |
| `LIST`, `DUMP <sesión>/<archivo>`, `LOG` | bajar datos por USB |

## Archivos por sesión (`/riderlab/sessions/<id>/`)

| Archivo | Contenido |
|---|---|
| `manifest.json` | rol, hw_id, firmware, `prev_session`, `ant_h_m`, `ref`, `receiver` (perfil, cfg, ruta, baud, Hz), baro; se reescribe cada 30 s |
| `pvt.ndjson` | NAV-PVT cada época: tow, utc+ns, fix, ok, sv, lat/lon, h (elip), msl, hAcc, vAcc, vel, pDOP |
| `sat.ndjson` | NAV-SAT ~1 Hz: `[gnssId, svId, cno, elev, azim, flags, prRes]`, usados, hash de usados |
| `dop.ndjson` | NAV-DOP ~1 Hz |
| `baro.ndjson` | 10 Hz (media de 5 lecturas a 50 Hz; BMP280 P×4 T×1 IIR16 ~83 Hz): `pa`, `temp_c` (die, no aire), `alt_m` ISA, `tow` (vía PPS), `gnss_hmsl`, `gnss_h`, `vacc` |
| `anchor_err.ndjson` | (ancla) cada época: dE/dN/dU vs REF (o vs media si no hay REF), valid/stab/dist, sv, hAcc, vAcc, pDOP, hash de sats usados, `pa`, `temp_c` |
| `anchor_summary.json` | (ancla) cada 30 s y al parar: media, std, N, duración, medianas, REF, offset, intervalos inválidos |
| `marks.ndjson` | session_start/stop, coloc, cp, bump, moved, avg_reset, ref, gnss_cfg |
| `gnss.ndjson`, `imu.ndjson`, `quality.ndjson` | formato previo (imu + `tow`; ancla imu a 10 Hz) |

Tiempo: cada muestra baro/IMU lleva `tow` (ms GPS de la semana) calculado con el flanco PPS
(`tsrc:"pps"`) o, sin PPS válido, con la llegada de NAV-PVT (`tsrc:"rx"`, decenas de ms de latencia).

## Post-proceso

```bash
cd hardware/firmware
python tools/anchor_correct.py --anchor SES_ANCLA --rider SES_MOTO --out salida \
    --rider-ant-h 1.0 [--ref lat,lon,h,ell] [--smooth-s 30] [--dyn-coef auto] [--gate lat,lon,15]
python -m unittest tools/test_anchor_correct.py -v
```

Hace: sincroniza por tiempo GPS; error del ancla suavizado (30 s, `--smooth-s`); comprueba
satélites comunes y marca tramos con < 70 % o < 6 comunes; descarta hAcc > 3 m o < 6 sats; valida
con los estáticos/COLOC sobre el punto (RMS antes/después) y usa deriva lineal si falta ancla;
barometría diferencial con offset de co-location (inicio/fin, interpolado, corrige la diferencia
de altura entre sensores con `ANT_H` y `--rider-ant-h`), escala con la temperatura (`--air-temp-c`;
si no, temperatura del sensor del ancla, aproximada), detección/ajuste de presión dinámica
(`dyn_flag`, `--dyn-coef auto`) y fusión complementaria con GPS (`--fuse-tau 120`).
Salida: `corrected.csv`, `corrected.gpx` y `corrected.geojson` con elevación (`h_rel` sobre la marca;
`h_abs` si la REF es medida), `profile.csv` (distancia vs elevación por vuelta y promedio),
`report.md`/`report.json` (RMS, vueltas, ascenso/descenso, avisos).

## Pendiente / validar en exterior

- Confirmar ruta de comandos al receptor (`cfg ok`) en **ambos** equipos; si `no-cmd-path`, ajustar
  el banco TXD del DIP del M135 (ver abajo) o usar `PINSCAN`.
- Flashear la **moto** con este mismo firmware (mismo perfil) antes de comparar.
- Medir RMS real en puntos de control y la deriva del offset baro entre co-locations.
- BMI270: 0.4.9 no cargaba el archivo de configuración de 8 KB y leía |a| = 0; 0.5.0 lo carga
  (`imu ok config ok`). Confirmar `IMU` ≈ 9.8 m/s² en ambos equipos.
- Unidad ancla (8 oct, tras ajustar DIP): NMEA llega por **G35 a 38400** con fix y PPS OK, pero
  **no hay ruta de comandos** (MON-VER sin respuesta en G13/15/16/17/2/5/26/12): el receptor queda
  de fábrica (1 Hz NMEA, sin UBX), así que el ancla no promedia (`n=0`, "sin fix bueno") ni graba
  pvt/sat/dop. Falta conectar el banco **TXD** del DIP (TX del host → NEO_RXD) a **G17, G15 o G12**
  (no G0). DIP para Core/Basic: host RX ← NEO_TXD: G35/G34/G13/G16; host TX → NEO_RXD:
  G0/G12/G15/G17; PPS: G34/G35/G0. Con el equipo apagado, un switch ON por banco.
