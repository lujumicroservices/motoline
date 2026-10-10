---
name: riderlab-estado
description: Estado vivo de RiderLab hardware (dispositivo ancla, logger de mapeo de circuitos) e indice de temas ya investigados con Experto RiderLab. Usar al retomar hardware, ancla, altitud/barometros, RTK, plano de tierra, 8 Horas, AiM, compras de partes, o al cerrar sesion ("actualiza estado", "cierra sesion").
---

# RiderLab - estado e indice

Ultima actualizacion: 2026-10-08 (Experto RiderLab)

Leer ANTES de investigar algo de nuevo. Si un tema esta en el indice, partir de ahi.
Complementa (no reemplaza) `.cursor/skills/hardware/SKILL.md`, `hardware/STATUS.md` y `.cursor/rules/experto-riderlab.mdc`.

## Como actualizar (al final de cada sesion)

1. Cambia la fecha de "Ultima actualizacion".
2. Mueve items entre **Hecho** / **En curso (borrador)** / **Pendiente**. Hecho = compilado, probado o en el repo; borrador = solo local, sin probar o sin commit.
3. Agrega temas nuevos al **Indice** con un puntero (archivo, PR, link). Una linea por tema, sin copiar la investigacion entera.
4. Si cambia la fase del logger, actualiza tambien `hardware/STATUS.md`.
5. Nada se sube a GitHub (commit/push) sin que Juan lo diga.

## 1. Dispositivo ancla (estacion de referencia en el paddock)

**Que es:** segundo M5Stack Basic v2.7 + modulo GNSS M135 (NEO-M9N L1, BMI270, BMP280, BMM150), fijo sobre un punto conocido. Mismo receptor y configuracion que la moto: su error de posicion (medido - referencia) se resta al de la moto (correccion diferencial en dominio de posicion). Tambien sirve de referencia de presion para la altitud de la moto (barometria diferencial).

**Etapa:** prototipo fisico + firmware de logger; modo ancla en programacion.

Hecho:
- Firmware logger `0.4.9-log` flasheado al ancla por COM8 desde este repo (2026-10-08). Hash verificado; arranque OK en banco. Sin prueba en exterior.
- Procedimiento: `hardware/firmware/ANCHOR.md`. Bitacora: `.cursor/rules/experto-riderlab.mdc`.
- Investigacion cerrada: plano de tierra, barometros, RTK barato (ver indice).

En curso / borrador (solo local, sin commit):
- Modo ancla en el firmware: rol ANCLA/MOTO (serial `ROLE ANCHOR|RIDER`), promedio de posicion (Welford + mediana) con indicador LISTO y `REF FROM AVG`, referencia `REF lat|lon|h|fuente|sigma|id`, altura de antena `ANT_H`, calidad de satelites (UBX NAV-PVT/NAV-SAT/NAV-DOP -> `pvt.ndjson`, `sat.ndjson`), `anchor_err.ndjson`, deteccion de movimiento por IMU, auto-inicio y tolerancia a cortes de energia, `anchor_summary.json`, Wi-Fi apagado y pantalla atenuada.
- Altitud: presion/temperatura/altitud BMP280 + altura GNSS (hMSL, vAcc) sincronizadas a tiempo GPS; barometria diferencial moto vs ancla; calibracion con ambos equipos juntos sobre el punto 2-3 min al inicio y al final.
- Script Python `anchor_correct.py` (con tests): corrige la sesion de la moto y exporta CSV/GPX/GeoJSON con elevacion + perfil vertical por distancia (por vuelta y promedio, subida/bajada total).
- Respaldo previo del firmware: `C:\Users\jvald\code\v1-firmware-backup-20261008`.

Pendiente / bloqueos:
1. Terminar, compilar y flashear el modo ancla (COM8, rol ANCHOR); revisar log de arranque.
2. Probar en pista con plano de tierra de acero 10-15 cm bajo la antena.
3. Medir la coordenada de referencia del punto (promedio largo del ancla o punto conocido).
4. Decidir compra de barometro BMP581 (uno por unidad, mismo modelo en ancla y moto) y diseno de puerto anti-viento.
5. Decidir commit/push. Hoy NADA del ancla esta en GitHub.

GitHub: solo PR #6 "BOM Pro (discrete L1/L2 RTK) beside BOM Standard (M5)" - borrador, abierto desde 2026-10-01, rama `discrete-rtk-bom`, archivo `hardware/BOM-pro.md`. Es BOM (ZED-F9P + base en paddock), sin firmware de ancla.

## 2. Dispositivo de mapeo de circuitos (logger de la moto)

**Que es:** M5Stack Basic v2.7 + M135 (+ Battery 13.2 + Bottom Base) que reemplaza al telefono para grabar la linea. Firmware en `hardware/firmware` (PlatformIO env `m5stack-basic`). Competidor de referencia: AiM Solo 2 / Solo 2 DL.

Hecho:
- Firmware `0.4.9-log`: GNSS a 25 Hz GPS-only (UART 38400, GGA+RMC), IMU 100 Hz, barometro 5 Hz, sesiones NDJSON en SD (`/riderlab/sessions/<id>/`), log de eventos `/riderlab/events.ndjson` (`LOG`, `LOGCLR`), subida por Wi-Fi a Azure (boton C), emparejamiento `PAIR`.
- 15 sesiones en nube (`logger-sessions/unpaired`, 3 oct); mapa `captures/cloud_rides.html`.
- Mapeos del circuito 8 Horas (24-25 sep) procesados (ver indice).

Falta:
- Validacion telefono vs logger segun `hardware/TRACK_COMPARE.md` (metricas en blanco).
- Sesiones recortadas al tope de 24 kB del POST.
- Precision actual esperada ~1-2.5 m (L1, sin RTK); el modo ancla busca bajar eso sin comprar RTK.
- Flash al 94.4%: considerar particion de 16 MB.
- Preguntas abiertas: antena SparkFun vs incluida; BLE en vivo (fuera de plan).
- Ruta a ~10 cm: RTK (ver indice). Decision de compra pendiente.

Detalle vivo: `hardware/STATUS.md`, `hardware/BOM.md`, `hardware/DECISIONS.md`, `hardware/CONTEXT.md`.

## 3. Indice de temas (con puntero)

| Tema | Conclusion corta | Donde vive |
|---|---|---|
| Barometro actual BMP280 | En el M135 (0x76), +-12 Pa ~ +-1 m relativo, hasta ~167 Hz; viento a 50 km/h ~10 m de error | `.cursor/rules/experto-riderlab.mdc`; chat Experto RiderLab 2026-10-05 |
| Mejores barometros | Recomendado **BMP581** (ruido 0.08 Pa, 0.5 Pa/K) sobre BMP390 (+-3 Pa, agotado) y DPS310 (descontinuado). En Zapopan (~822 hPa) 1 Pa ~ 10.5 cm | Esta skill; chat 2026-10-08 |
| Donde comprar barometros | BMP581: DFRobot Gravity Amazon MX $329.76 MXN (amazon.com.mx/dp/B0H8S983PM); Adafruit 6407 DigiKey MX US$9.95. ICP-10111 UNIT Amazon MX $144.90 (B0GJFS5F35). BMP390 Amazon MX $201.23 (B0GMVBBZ18). Port A da 5 V: usar placas con regulador; Qwiic necesita cable a Grove | Chat 2026-10-08 (precios de ese dia) |
| Tiendas en Zapopan/GDL | HeTPro (Marcelino Garcia Barragan 1613, 33 3572 8211, distribuye Adafruit/Seeed), Talos (33 2613 2269), Mexbit Zapopan (Guadalupe Victoria 133A), Electronica Zapopan, Elementos Electronicos (33 3613 2318), Steren | Chat 2026-10-08 |
| Puerto anti-viento del barometro | Camara con membrana PTFE, orificio lateral, mismo diseno en ancla y moto; calibrar error vs velocidad (v^2) | Chat 2026-10-08 |
| Altitud / barometria diferencial | Presion del ancla quita deriva del clima; fusion con altura GNSS en Python | `hardware/firmware/ANCHOR.md` (al terminar modo ancla) |
| Plano de tierra | Disco de acero >=10 cm (ideal 15) centrado bajo la antena; unos mm de plastico no importan. Ref: u-blox UBX-15030289, ArduSimple (EUR 8.20), SparkFun (US$7.25) | `.cursor/rules/experto-riderlab.mdc` |
| RTK barato | LC29H(EA) rover L1/L5 10 Hz + LC29H(BS) base (~US$100 + antenas); LG290P Waveshare US$89.99 (L1/L2/L5, 20 Hz, PPK, limite 4 g); UM980 ~US$150 como base. No LC29H(DA) (RTK 1 Hz) | `.cursor/rules/experto-riderlab.mdc`; chat 2026-10-05 y 2026-10-08 |
| RTK caro (BOM Pro) | ZED-F9P ~US$495/unidad + ~US$443 base | PR #6, rama `discrete-rtk-bom`, `hardware/BOM-pro.md` |
| Competencia AiM Solo 2 | Referencia de hardware; BOM actual ~1-2.5 m, cerca o algo peor que AiM | `hardware/BOM.md`, `hardware/DECISIONS.md`, `hardware/CONTEXT.md` |
| Circuito 8 Horas (Zapopan) | Av. Las Torres, Paraisos del Colli; vuelta 1.33-1.6 km, ancho ~7 m, centro 20.6663,-103.4598 | `.cursor/skills/circuit-8h/`, `8horas/`, `docs/www/_dist/simm/circuit8h_*` |
| Estrategia punto de referencia estatico | Ancla en punto conocido + mapeo con M5; mismo receptor y satelites comunes | `hardware/firmware/ANCHOR.md` |
| Bot hermano | "Experto Electronica RiderLab" para dudas de electronica | Grok Bot |
| Validacion telefono vs logger | Protocolo listo, sin datos | `hardware/TRACK_COMPARE.md` |
| Pantalla del ancla/M5 | Que muestra la pantalla en 0.5.0-anchor (ANCLA paginas POSICION/CALIDAD GNSS, RIDER, menu, botones, atenuado, estado actual) | `docs/ANCHOR_SCREEN.md` |