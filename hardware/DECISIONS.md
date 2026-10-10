# Decisiones cerradas

No reabrir estas en un chat nuevo salvo que el usuario lo pida.

1. **Menos que el teléfono.** Hardware = GNSS + IMU 6 ejes + MCU + storage/display/BLE. Sin mag, sin barómetro como requisito.
2. **Trazada es métrica #1** para este dispositivo (pilotos pro, circuito).
3. **BOM actual = M9N + antena buena**, no RTK. Precisión esperada ~**1–2.5 m**, **10–25 Hz**, cerca / un poco peor que AiM.
4. **Lote de diseño: 10 unidades.**
5. **Display sí** (pedido del partner). Se reemplazó StampS3A + microSD suelta por **M5Stack Basic v2.7** (MCU + IPS 2.0" 853 nit + slot SD).
6. **Competidor principal de hardware: AiM Solo 2 / Solo 2 DL**, no el celular.
7. **Renders honestos:** stack M5Stack real, no dash comercial. Las primeras imágenes se sobre-diseñaron y se corrigieron.
8. Sourcing: se cotizó USA (M5Stack / SparkFun) y se pidió China; el BOM vivo sigue con SKUs M5Stack porque son los que apilan. China es para bajar BOM en una siguiente pasada, no para cambiar chips a ciegas.
9. **DIP M135 medido, no deducido de los docs (Basic):** en esta unidad **TXD switch 4 → GPIO35**, con NMEA 38400 limpio (`bad=0`). El orden del banco está corrido respecto a la tabla de M5, así que el mapeo se verifica con el escáner de pines del firmware (BtnB al arrancar) y no con la documentación.
   - **GPIO35 es solo-entrada:** sirve para leer NMEA, no para mandar UBX por ese pin. El rate 10–25 Hz se manda por I2C DDC 0x42 y/o cazando NEO_RXD en un GPIO de salida (firmware 0.3.3).
   - **Nunca rutear TXD a GPIO0 ni GPIO12:** son strapping pins. Con GPIO12 en alto al reset el ESP32 pone la flash a 1.8 V y no arranca (`flash read err`); GPIO0 en bajo entra en modo descarga.
   - `M5.begin()` pone **GPIO15 en output LOW** en `board_M5Stack` (parche de WiFi del M5GO base). Hay que liberar el pin (`gpio_reset_pin`) antes de `Serial2.begin`, o el NEO_TXD queda cortocircuitado y el UART lee 0 bytes.
10. **Power:** Battery 13.2 activa. Bottom Base original solo como tapa mecánica con switch en **0** (su batería deshabilitada). USB-C solo en el Basic.
11. **Firmware path:** health-check + logger crudo SD (`hardware/firmware` 0.2.0); analytics después. Baro/mag raw si el bus lo permite.
12. **Post-rodada cloud:** cerca del Wi‑Fi 2.4 guardado, el logger sube solo. HTTPS a `logger-ingest` con `WiFiClientSecure` + `setInsecure` (ESP32 no trae el CA de Azure; la clave va en `X-Logger-Key`). GET de calentamiento + POST. Reintentos si el enlace falla. Radio apagado solo sin cola o al REC. Blob `logger-sessions/{device}/{session}/`. Serial `WIFI ssid|pass` y `AZURE <key>`. SD se borra **solo** tras HTTP 2xx.
13. **Import fallback:** carpeta sesión NDJSON → SQLite local → sync (Settings → M5 Logger).
14. **Event log de producción:** `/riderlab/events.ndjson` (rota a `.bak` a ~120 KB). Serial + SD. Niveles E/W/I. GNSS 1 Hz no va al archivo. USB: `LOG` / `LOGCLR`.

## Escalones explícitamente *no* elegidos (aún)

- RTK F9P + base en paddock (mejor línea, más costo/ops).
- Solo logger sin pantalla.
- Replicar ECU/CAN de AiM DL.
- Pines UART “default” G16/G17 (conflicto con DIP verificado actual).
- BLE telemetría en vivo (después del pipeline SD/Wi‑Fi).
