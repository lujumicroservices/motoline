# Contexto — logger de hardware RiderLab

## Qué es esto

Subproyecto **aparte de la app / shop / Play**. Objetivo: un dispositivo en la moto que capture las métricas de rodada **sin el teléfono como sensor**. El teléfono (RiderLab) sigue siendo UI, pits y sync.

## Usuario y escenario

Pilotos **profesionales en un circuito específico** (layout fijo, cielo abierto). La **trazada** (línea en mapa, vuelta a vuelta) es crítica. Un partner pidió **display en moto**.

Competidor de referencia: **AiM Solo 2 / Solo 2 DL** (no el teléfono).

## Qué captura el teléfono hoy (referencia de producto)

| Sensor | Uso en RiderLab | ¿Va en el hardware? |
|--------|-----------------|---------------------|
| GNSS (lat/lng, speed Doppler, heading, accuracy) | Mapa, distancia, curvas, frenos, tramos | **Sí — núcleo** |
| IMU 6 ejes accel+gyro ~50 Hz | Lean L/R, max lean, skill/replay | **Sí — núcleo** |
| Barómetro | Se guarda; no es el producto | No |
| Magnetómetro | Solo Lean Lab | No |
| Cámara / live share | Otro producto | No |

## Qué define una buena trazada (en este orden)

1. Densidad de puntos (Hz) — ápice y radio
2. Continuidad — sin huecos ni teleports
3. Poco jitter lateral
4. Repetibilidad entre vueltas
5. CEP / multipath

## Tesis de costo

Dos lanes, no uno:

- **M5 / M9N** ([BOM.md](BOM.md)): costo eficiente, ~$128/u, sin RTK. Precisión esperada ~1–2.5 m.
- **Componentes sueltos + RTK** ([BOM-rtk.md](BOM-rtk.md)): el usuario lo abrió el 2026-10-01. Doble banda L1/L2, base en paddock, ~$495/rover + una base de ~$443. Sigue debajo de un lote de Solo 2 DL, y ya no es el BOM de $128.

## Expectativa visual (no inflar)

Ningún lane es un Solo 2 sellado. El M5 es un stack maker (Basic 54×54 mm + M135). El RTK es breakouts cableados en caja de proyecto. UI DIY. No generar renders que parezcan producto comercial.

## Relación con el repo de software

- App: `apps/mobile` — lean IMU, GPS denso, RideRecorder.
- Este folder: diseño, BOM, firmware futuro, montaje.
- No mezclar deploys de shop/landing/Play en chats de hardware salvo que el usuario lo pida.
