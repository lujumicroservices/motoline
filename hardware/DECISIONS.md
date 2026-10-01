# Decisiones cerradas

No reabrir estas en un chat nuevo salvo que el usuario lo pida.

1. **Menos que el teléfono.** Hardware = GNSS + IMU 6 ejes + MCU + storage/display/BLE. Sin mag, sin barómetro como requisito.
2. **Trazada es métrica #1** para este dispositivo (pilotos pro, circuito).
3. **BOM Standard = M9N + antena buena**, no RTK. Precisión esperada ~**1–2.5 m**, **10–25 Hz**, cerca / un poco peor que AiM. Sigue vigente para [BOM-standard.md](BOM-standard.md).
4. **Lote de diseño: 10 unidades.**
5. **Display sí** (pedido del partner). Se reemplazó StampS3A + microSD suelta por **M5Stack Basic v2.7** (MCU + IPS 2.0" 853 nit + slot SD).
6. **Competidor principal de hardware: AiM Solo 2 / Solo 2 DL**, no el celular.
7. **Renders honestos:** stack M5Stack real, no dash comercial. Las primeras imágenes se sobre-diseñaron y se corrigieron.
8. Sourcing del BOM Standard: se cotizó USA (M5Stack / SparkFun) y se pidió China; ese BOM sigue con SKUs M5Stack porque son los que apilan. China es para bajar costo, no para cambiar chips a ciegas. El BOM Pro arranca con breakouts de catálogo (SparkFun / DigiKey / Adafruit); el módulo F9P suelto en PCB propia queda para cuando el proto fije en pista.

9. **2026-10-01 — BOM Pro, pedido por el usuario.** Componentes sueltos, no stack M5. GNSS doble banda **L1/L2 ZED-F9P** con RTK y **una base en paddock** (radio 915 MHz). Detalle, precios y límites de precisión en [BOM-pro.md](BOM-pro.md). No sustituye al BOM Standard. Centímetros solo con RTK fixed; sin correcciones el F9P se queda en ~1.5 m CEP.
10. **Nombres.** BOM Pro = el RTK de partes sueltas. BOM Standard = el stack M5/M9N. El usuario fijó estos nombres el 2026-10-01.

## Escalones explícitamente *no* elegidos (aún)

- RTK dentro del BOM Standard (el F9P vive solo en el BOM Pro).
- Quectel LG290P (más bandas y 20 Hz; no es el doble banda elegido).
- Solo logger sin pantalla.
- Replicar ECU/CAN de AiM DL.
