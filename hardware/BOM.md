# BOM — 10 unidades (config viva)

**Perfil:** NEO-M9N + antena activa + IMU BMI270 + display 2" + Battery 13.2.  
**Precisión de línea (esperada):** ~1–2.5 m, 10–25 Hz. Cerca / un poco peor que AiM Solo 2.  
**Costo partes:** ~**$128 / unidad**, ~**$1,270** las 10.  
**Vs AiM Solo 2 DL:** ~$500–900/u, 10× ≈ $5k–9k.

| Cant. | Pieza | Rol | Precio u. | Subtotal | Link |
|------:|-------|-----|----------:|---------:|------|
| 10 | M5Stack **Module GNSS M135** (NEO-M9N + BMI270) | GPS + IMU | $45.00 | $450 | [M5Stack](https://shop.m5stack.com/products/gnss-module-with-barometric-pressure-imu-magnetometer-sensors) |
| 10 | M5Stack **Basic Core v2.7** | MCU + IPS 2.0" 853 nit + microSD | $39.90 | $399 | [M5Stack](https://shop.m5stack.com/products/esp32-basic-core-lot-development-kit-v2-7) |
| 10 | M5Stack **Battery Module 13.2** (1500 mAh) | Autonomía (vs 110 mAh del Basic) | $10.50 | $105 | [M5Stack](https://shop.m5stack.com/products/battery-module-13-2-1500mah) |
| 10 | Antena GNSS magnética SMA 3 m | Antena (ROI #1 de posición) | $16.50 | $165 | [SparkFun](https://www.sparkfun.com/gps-gnss-magnetic-mount-antenna-3m-sma.html) |
| 10 | Buck 12 V → 5 V (MP1584 / Mini360) | Power de moto (alt. a USB 5 V) | ~$2 | ~$20 | LCSC / Amazon / AliExpress |
| 10 | Caja IP65 (visor o recorte de pantalla) | Envolvente prototipo | ~$10 | ~$100 | Amazon / AliExpress |
| 10 | Ground plane ~10 cm + tornillería | Antena | ~$3 | ~$30 | Ferretería / Amazon |

**Power (elige según la moto):** Battery 13.2 (portable) **o** USB 5 V de la moto **o** buck 12→5 V. No hace falta los tres a la vez.

**Qué va en pantalla (firmware, no existe aún):** speed, lean, lap/Δt, estado GPS.

**Montaje:** antena en punto alto despejado + ground plane; stack Basic **arriba** / Battery + M135 debajo; caja project-box, no CNC.

## Qué no está en este BOM

- Base RTK / ZED-F9P
- StampS3A (lo absorbió el Basic)
- microSD suelta (slot en el Basic)

Precios de catálogo al 19 Sep 2026; revalidar al comprar.
