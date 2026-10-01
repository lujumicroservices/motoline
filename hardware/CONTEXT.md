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

- **BOM Standard** ([BOM-standard.md](BOM-standard.md)): stack M5 / M9N, ~$128/u, sin RTK. Precisión esperada ~1–2.5 m.
- **BOM Pro** ([BOM-pro.md](BOM-pro.md)): componentes sueltos, doble banda L1/L2, base en paddock, ~$495/rover + una base de ~$443. El usuario lo abrió el 2026-10-01 y le puso este nombre el mismo día.

## Expectativa visual (no inflar)

Ningún lane es un Solo 2 sellado. Standard es un stack maker (Basic 54×54 mm + M135). Pro es breakouts cableados en caja de proyecto. UI DIY. No generar renders que parezcan producto comercial.

## Relación con el repo de software

- App: `apps/mobile` — lean IMU, GPS denso, RideRecorder.
- Este folder: diseño, BOM, firmware futuro, montaje.
- No mezclar deploys de shop/landing/Play en chats de hardware salvo que el usuario lo pida.
