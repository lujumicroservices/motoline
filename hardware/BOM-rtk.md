# BOM — componentes sueltos, GNSS doble banda + RTK

**Perfil:** rover cableado (no stack M5) + **una base en paddock** compartida.  
**Chip:** u-blox **ZED-F9P**, bandas **L1/L2** (no L1 solo, no el F10).  
**Precisión de línea (esperada en pista):**

| Estado del fix | Qué esperar |
|----------------|-------------|
| **RTK fixed**, cielo abierto, base quieta, baseline del circuito | Clase centímetro. Datasheet: **0.01 m + 1 ppm CEP**. En moto (vibración, carenado, plano de tierra imperfecto) contar **unos centímetros a ~10–20 cm**, no el 1 cm de laboratorio. |
| **RTK float** | Decímetros. No tratarlo como línea buena. |
| **Sin correcciones** (doble banda suelta) | ~**1.5 m CEP** autónomo. Mejor que el M9N, y no es el motivo de este BOM. |

El centímetro **no existe** sin correcciones (base o NTRIP) y sin `carrSoln = fixed`. Hay que loguear el tipo de fix.

**Tasa:** el F9P no da 20 Hz RTK con las cuatro constelaciones. En las revisiones habituales, RTK es ~**8 Hz** con GPS+GLO+GAL+BDS, ~**10 Hz** con GPS+GAL, y **20 Hz** solo con GPS. Objetivo de firmware: **10 Hz GPS+GAL** (subir si el módulo comprado lo aguanta). A 150 km/h, 10 Hz son ~4 m entre puntos; 20 Hz, ~2 m.

**Costo de catálogo (1 oct 2026):** ~**$495 / rover**, ~**$443** la base (una sola).  
Proto: **1 rover + 1 base ≈ $940**. Diez rovers + 1 base ≈ **$5,400**.  
Vs M5/M9N (~$128/u, sin RTK) y vs AiM Solo 2 / Solo 2 DL (~$500–900/u).

Sigue siendo una **caja de prototipo cableada**, no un dash sellado.

## Rover (×10 en el diseño, comprar ×1 primero)

| Cant. | Pieza | Rol | Precio u. | Subtotal | Link |
|------:|-------|-----|----------:|---------:|------|
| 10 | SparkFun **GPS-RTK-SMA** (ZED-F9P) | GNSS L1/L2, rover, UART1 datos + UART2 RTCM, PPS | $259.95 | $2,599.50 | [SparkFun](https://www.sparkfun.com/sparkfun-gps-rtk-sma-breakout-zed-f9p-qwiic.html) |
| 10 | Antena activa **ANN-MB-00** (L1/L2, mag, SMA, 5 m) | Antena. Una de parche L1 no sirve | $109.95 | $1,099.50 | [SparkFun GPS-15192](https://www.sparkfun.com/gnss-multi-band-magnetic-mount-antenna-5m-sma.html) |
| 10 | **ESP32-S3-DevKitC-1-N8R8** | MCU, log, BLE, pantalla. 8 MB flash + 8 MB PSRAM | $15.00 | $150.00 | [DigiKey](https://www.digikey.com/en/products/detail/espressif-systems/ESP32-S3-DEVKITC-1-N8R8/15295894) |
| 10 | SparkFun **BMI270** (6 ejes) | Lean. Sin mag, sin barómetro | $17.58 | $175.80 | [SparkFun](https://www.sparkfun.com/sparkfun-micro-6dof-imu-breakout-bmi270-qwiic.html) |
| 10 | Adafruit **2.0" IPS ST7789** + slot microSD (n.º 4311) | Pantalla + almacenamiento | $19.95 | $199.50 | [Adafruit](https://www.adafruit.com/product/4311) |
| 10 | microSD 32 GB | Log de sesión | ~$8 | ~$80 | Amazon / local |
| 10 | Adafruit **RFM95W** 915 MHz (n.º 3072) | Recibe RTCM de la base | $19.95 | $199.50 | [Adafruit](https://www.adafruit.com/product/3072) |
| 10 | Hilo ~82 mm (λ/4 a 915 MHz) | Antena del radio | ~$1 | ~$10 | — |
| 10 | Pololu **D24V22F5** (5 V, 2.5 A, entrada hasta 36 V) | 12 V de moto → 5 V | $18.95 | $189.50 | [Pololu](https://www.pololu.com/product/2858) |
| 10 | Fusible 2 A + portafusible + TVS (SMBJ33A o equivalente) + conector SAE | El buck no aguanta un load dump | ~$8 | ~$80 | DigiKey / ferretería |
| 10 | Disco de acero ~12 cm bajo la antena | Plano de tierra L1/L2 | ~$5 | ~$50 | Ferretería |
| 10 | Caja IP65 + cable dupont / headers | Envolvente. No es CNC | ~$12 | ~$120 | Amazon / AliExpress |

**Rover ×10 ≈ $4,953.** Por unidad ≈ **$495**.

La pantalla de $20 es IPS normal, **no** los 853 nit del Basic v2.7. En sol de pista puede hacer falta visera o un panel más brillante. No darla por leída hasta probarla.

## Base de paddock (×1, no por moto)

Una base quieta alimenta a todos los rovers del mismo día. Si se mueve, la línea absoluta se corre.

| Cant. | Pieza | Rol | Precio u. | Subtotal | Link |
|------:|-------|-----|----------:|---------:|------|
| 1 | SparkFun GPS-RTK-SMA (ZED-F9P) | Base: survey-in o coordenada fija, sale RTCM | $259.95 | $259.95 | [SparkFun](https://www.sparkfun.com/sparkfun-gps-rtk-sma-breakout-zed-f9p-qwiic.html) |
| 1 | Antena ANN-MB-00 | Misma antena, fija sobre el disco | $109.95 | $109.95 | [SparkFun](https://www.sparkfun.com/gnss-multi-band-magnetic-mount-antenna-5m-sma.html) |
| 1 | ESP32-S3-DevKitC-1-N8R8 | Lee RTCM y lo manda al radio | $15.00 | $15.00 | [DigiKey](https://www.digikey.com/en/products/detail/espressif-systems/ESP32-S3-DEVKITC-1-N8R8/15295894) |
| 1 | Adafruit RFM95W 915 MHz | Tx de correcciones | $19.95 | $19.95 | [Adafruit](https://www.adafruit.com/product/3072) |
| 1 | Hilo ~82 mm | Antena del radio, en alto | ~$1 | ~$1 | — |
| 1 | Disco de acero ~12 cm | Plano de tierra de la base | ~$5 | ~$5 | Ferretería |
| 1 | Power bank USB o 5 V de paddock | La base no va en la moto | ~$20 | ~$20 | — |
| 1 | Caja | Que no se mueva en el día | ~$12 | ~$12 | — |

**Base ≈ $443.** Proto 1+1 ≈ **$940**. Diez rovers + base ≈ **$5,400**.

Survey-in basta para comparar vueltas **entre sí** si la base no se toca. Para clavar la línea sobre un mapa georreferenciado hace falta la coordenada de la base en el mismo marco.

## Cómo se conecta (rover)

No es un stack. Cada pieza va por su bus.

- **12 V moto** → fusible → TVS → Pololu 5 V → VIN del ESP32, del F9P y de la pantalla.
- **UART:** ESP32 ↔ UART1 del F9P (UBX: posición, velocidad, tipo de fix).
- **RTCM:** RFM95 (SPI) → ESP32 → UART2 RX del F9P. Loguear edad de la corrección.
- **I2C:** BMI270, atornillado al chasis, no a la tapa de la pantalla.
- **SPI aparte:** pantalla + microSD (el ESP32-S3 tiene dos SPI; el radio no comparte bus con la SD).
- **PPS** del F9P → un GPIO, para alinear IMU y GNSS.
- **Antena** en punto alto y despejado, disco de acero debajo, SMA al breakout (el breakout alimenta la antena activa).

La base es el mismo GNSS en modo base: UART de RTCM → ESP32 → RFM95. Radio en **915 MHz** (ISM América). Confirmar la banda permitida antes de transmitir. Aire útil para RTCM ~1 Hz: SF bajo y ancho de banda ancho (p. ej. SF7 / BW250 o BW500), no el modo de máxima distancia. El circuito cabe en ~2 km a línea de vista; gradas y cuerpo del piloto bajan eso. Si la edad de corrección pasa de ~2 s, el fixed se degrada.

## Qué va en pantalla y en la SD

Speed, lean, lap/Δt, y el estado **NONE / FLOAT / FIXED** más la edad RTCM. Sin el estado de fix, una línea “RTK” miente.

## Qué no está

- Stack M5 (Basic, M135, Battery 13.2). Ese BOM sigue en [BOM.md](BOM.md), sin RTK.
- Antena magnética de una sola banda.
- Módulo suelto ZED-F9P en PCB propia. Los breakouts son el proto. Una placa carrier es el paso para bajar los ~$260 del receptor.
- NTRIP de pago. Solo si el LoRa no cubre el circuito.
- Magnetómetro, barómetro, CAN de la moto.

## Alternativa no elegida

**Quectel LG290P** (SparkFun, $189.95): L1/L2/L5/E6, RTK hasta 20 Hz con más constelaciones, más barato que el breakout F9P. No es doble banda. Si el límite de 8–10 Hz del F9P duele en el ápice, se cambia esta línea y la antena pasa a ser all-band (ANN-MB2, ~$120), no la ANN-MB-00.

Precios de lista al **1 oct 2026**. Revalidar al armar el carrito.
