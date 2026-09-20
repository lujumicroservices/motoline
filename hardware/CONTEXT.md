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

Costo eficiente, **no** logger de $900. Con trazada crítica: antena + chip razonable + fusión IMU + software. RTK (base en paddock) queda como **escalón posterior**, no el BOM actual.

## Expectativa visual (no inflar)

El prototipo es **stack maker M5Stack** (Basic 54×54 mm + módulo GNSS), no un Solo 2 sellado. UI DIY. No generar renders que parezcan producto comercial.

## Relación con el repo de software

- App: `apps/mobile` — lean IMU, GPS denso, RideRecorder.
- Este folder: diseño, BOM, firmware futuro, montaje.
- No mezclar deploys de shop/landing/Play en chats de hardware salvo que el usuario lo pida.
